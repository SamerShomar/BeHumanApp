import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/notifications/domain/app_notification.dart';

/// How many notifications are kept on screen. Older ones stay in Firestore but
/// are not fetched — an unbounded stream would grow forever on a shared feed.
const int notificationFeedLimit = 50;

/// Every notification on record, newest first, regardless of audience.
final notificationFeedProvider =
    StreamProvider.autoDispose<List<AppNotification>>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(notificationFeedLimit)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => AppNotification.fromJson({'id': doc.id, ...doc.data()}))
          // A malformed document should not blank the whole feed.
          .whereType<AppNotification>()
          .toList());
});

/// The notifications the signed-in user should actually see.
///
/// Filtering happens here rather than in the query because audience membership
/// depends on the reader's role, which Firestore cannot express in a `where`.
final myNotificationsProvider = Provider.autoDispose<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserStreamProvider).valueOrNull;
  if (user == null) return const [];

  final feed = ref.watch(notificationFeedProvider).valueOrNull ?? const [];
  return feed.where((n) => n.isVisibleTo(user)).toList();
});

/// Drives the badge on the bell.
final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final user = ref.watch(currentUserStreamProvider).valueOrNull;
  if (user == null) return 0;

  return ref
      .watch(myNotificationsProvider)
      .where((n) => !n.isReadBy(user.uid))
      .length;
});

/// Publishes events and tracks what has been read.
class NotificationService {
  NotificationService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('notifications');

  /// Announces a newly submitted proposal to the people who review them.
  ///
  /// Failures are swallowed on purpose: the proposal itself is already saved
  /// by this point, and telling the submitter "upload failed" because a
  /// notification could not be written would be wrong.
  Future<void> proposalSubmitted({
    required AppUser actor,
    required String proposalId,
    required String title,
  }) =>
      _publish(AppNotification(
        id: 'n${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.proposal,
        titleKey: 'notification_proposal_title',
        bodyKey: 'notification_proposal_body',
        params: {'name': actor.name, 'title': title},
        audience: NotificationAudience.reviewers,
        actorUid: actor.uid,
        createdAt: DateTime.now(),
        route: '/proposals',
      ));

  /// Announces a financial movement to the whole team.
  Future<void> transactionAdded({
    required AppUser actor,
    required String transactionId,
    required String type,
    required double amount,
  }) =>
      _publish(AppNotification(
        id: 'n${DateTime.now().millisecondsSinceEpoch}',
        type: NotificationType.transaction,
        titleKey: type == 'income'
            ? 'notification_income_title'
            : 'notification_expense_title',
        bodyKey: 'notification_transaction_body',
        params: {
          'name': actor.name,
          'amount': amount.toStringAsFixed(2),
        },
        audience: NotificationAudience.all,
        actorUid: actor.uid,
        createdAt: DateTime.now(),
        route: '/financial',
      ));

  Future<void> _publish(AppNotification notification) async {
    try {
      await _collection.doc(notification.id).set(notification.toJson());
    } catch (_) {
      // See the note on proposalSubmitted.
    }
  }

  /// Marks one notification as read by [uid].
  ///
  /// `arrayUnion` rather than a read-modify-write so two people opening the
  /// feed at once cannot erase each other's read state.
  Future<void> markRead(String notificationId, String uid) async {
    await _collection.doc(notificationId).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }

  Future<void> markAllRead(Iterable<AppNotification> notifications, String uid) async {
    final unread = notifications.where((n) => !n.isReadBy(uid));
    if (unread.isEmpty) return;

    final batch = _firestore.batch();
    for (final notification in unread) {
      batch.update(_collection.doc(notification.id), {
        'readBy': FieldValue.arrayUnion([uid]),
      });
    }
    await batch.commit();
  }

  /// Removes a notification for everyone. Restricted to admins by the rules.
  Future<void> delete(String notificationId) =>
      _collection.doc(notificationId).delete();
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(firebaseFirestoreProvider)),
);
