import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/notifications/domain/app_notification.dart';
import 'package:be_human_app/features/notifications/domain/relative_time.dart';
import 'package:be_human_app/features/notifications/presentation/providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserStreamProvider).valueOrNull;
    final feed = ref.watch(notificationFeedProvider);
    final mine = ref.watch(myNotificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'notifications')),
        actions: [
          if (unread > 0 && user != null)
            TextButton(
              onPressed: () => _markAllRead(context, ref, mine, user.uid),
              child: Text(AppLocalizations.of(context, 'mark_all_read')),
            ),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('${AppLocalizations.of(context, 'error_generic')}: $e'),
          ),
        ),
        data: (_) {
          if (user == null || mine.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(height: 12),
                  Text(AppLocalizations.of(context, 'no_notifications')),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: mine.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _NotificationTile(
              notification: mine[index],
              user: user,
            ),
          );
        },
      ),
    );
  }

  Future<void> _markAllRead(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> notifications,
    String uid,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationServiceProvider).markAllRead(notifications, uid);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification, required this.user});

  final AppNotification notification;
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final isRead = notification.isReadBy(user.uid);
    final age = RelativeTime.describe(notification.createdAt);

    return ListTile(
      // Unread entries are tinted rather than badged: the whole row reads as
      // new at a glance, which matters on a small phone screen.
      tileColor: isRead ? null : scheme.primary.withOpacity(0.06),
      leading: CircleAvatar(
        backgroundColor: notification.type == NotificationType.proposal
            ? scheme.primary
            : Colors.green,
        child: Icon(
          notification.type == NotificationType.proposal
              ? Icons.description_outlined
              : Icons.account_balance_wallet_outlined,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(
        AppLocalizations.of(context, notification.titleKey, notification.params),
        style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context, notification.bodyKey, notification.params)),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(context, age.key, age.params),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: user.isAdmin
          ? IconButton(
              icon: Icon(Icons.delete_outline, color: scheme.error),
              tooltip: AppLocalizations.of(context, 'delete'),
              onPressed: () => _delete(context, ref),
            )
          : null,
      onTap: () => _open(context, ref, isRead),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, bool isRead) async {
    final router = GoRouter.of(context);
    final route = notification.route;

    // Marking read must not block navigation, so it is fired first and its
    // failure ignored — a stale badge is a smaller problem than a dead tap.
    if (!isRead) {
      try {
        await ref
            .read(notificationServiceProvider)
            .markRead(notification.id, user.uid);
      } catch (_) {
        // Ignored on purpose; see above.
      }
    }

    if (route != null) router.go(route);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationServiceProvider).delete(notification.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
