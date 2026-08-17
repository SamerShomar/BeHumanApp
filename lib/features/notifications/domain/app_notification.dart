import 'package:be_human_app/features/auth/domain/entities/app_user.dart';

/// Who a notification is meant for.
///
/// Stored as a plain string on the document so the audience is decided once,
/// by whoever published the event, rather than re-derived by every reader.
abstract final class NotificationAudience {
  /// Everyone with a profile.
  static const String all = 'all';

  /// Only the people who act on proposals — managers and admins.
  static const String reviewers = 'reviewers';
}

/// What happened. Drives the icon and where tapping the entry goes.
abstract final class NotificationType {
  static const String proposal = 'proposal';
  static const String transaction = 'transaction';
}

/// One event worth telling the team about.
///
/// The text is stored as translation keys plus parameters, never as a finished
/// sentence: the person who publishes it and the people who read it may be
/// using different languages, and a notification written in Arabic would stay
/// Arabic on a Dutch reviewer's screen.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.titleKey,
    required this.bodyKey,
    required this.params,
    required this.audience,
    required this.actorUid,
    required this.createdAt,
    this.route,
    this.readBy = const [],
  });

  final String id;
  final String type;
  final String titleKey;
  final String bodyKey;
  final Map<String, String> params;
  final String audience;

  /// The person whose action produced this. They are never notified about
  /// their own action.
  final String actorUid;

  final DateTime createdAt;

  /// Where tapping the notification should take the reader.
  final String? route;

  /// Uids that have already seen it. An array on the shared document rather
  /// than a per-user copy: the team is small, and this keeps one write per
  /// event instead of one per recipient.
  final List<String> readBy;

  bool isReadBy(String uid) => readBy.contains(uid);

  bool isVisibleTo(AppUser user) {
    // Your own action is not news to you.
    if (actorUid == user.uid) return false;

    return switch (audience) {
      NotificationAudience.reviewers => user.canApprove,
      NotificationAudience.all => true,
      // An unknown audience is shown to nobody rather than to everybody:
      // a notification is easier to miss than to un-send.
      _ => false,
    };
  }

  static AppNotification? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (id is! String || createdAt == null) return null;

    return AppNotification(
      id: id,
      type: json['type'] as String? ?? '',
      titleKey: json['titleKey'] as String? ?? '',
      bodyKey: json['bodyKey'] as String? ?? '',
      params: switch (json['params']) {
        final Map<Object?, Object?> raw => {
            for (final entry in raw.entries)
              entry.key.toString(): entry.value?.toString() ?? '',
          },
        _ => const {},
      },
      audience: json['audience'] as String? ?? NotificationAudience.all,
      actorUid: json['actorUid'] as String? ?? '',
      createdAt: createdAt,
      route: json['route'] as String?,
      readBy: switch (json['readBy']) {
        final List<Object?> raw => raw.whereType<String>().toList(),
        _ => const [],
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'titleKey': titleKey,
        'bodyKey': bodyKey,
        'params': params,
        'audience': audience,
        'actorUid': actorUid,
        'createdAt': createdAt.toIso8601String(),
        if (route != null) 'route': route,
        'readBy': readBy,
      };
}
