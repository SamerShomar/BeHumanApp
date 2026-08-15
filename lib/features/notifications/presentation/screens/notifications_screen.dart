import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/widgets/glass.dart';
import 'package:be_human_app/core/widgets/state_views.dart';
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
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: AppLocalizations.of(context, 'notifications'),
        actions: [
          if (unread > 0 && user != null)
            TextButton(
              onPressed: () => _markAllRead(context, ref, mine, user.uid),
              child: Text(AppLocalizations.of(context, 'mark_all_read')),
            ),
        ],
      ),
      body: feed.when(
        loading: () => const LoadingStateView(),
        error: (e, _) => ErrorStateView(error: e),
        data: (_) {
          if (user == null || mine.isEmpty) {
            return EmptyStateView(
              icon: Icons.notifications_none,
              message: AppLocalizations.of(context, 'no_notifications'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 120,
            ),
            itemCount: mine.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _NotificationTile(notification: mine[index], user: user),
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
    final theme = Theme.of(context);
    final isRead = notification.isReadBy(user.uid);
    final age = RelativeTime.describe(notification.createdAt);
    final isProposal = notification.type == NotificationType.proposal;
    // Money in and money out are not the same news, so they are not the same
    // colour — the title key is what distinguishes them.
    final accent = isProposal
        ? AppColors.brand
        : notification.titleKey == 'notification_expense_title'
            ? AppColors.danger
            : AppColors.success;

    return GlassCard(
      // Unread entries are washed with the accent rather than badged: the
      // whole card reads as new at a glance, which matters on a small screen.
      tint: isRead ? null : accent,
      onTap: () => _open(context, ref, isRead),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Icon(
              isProposal
                  ? Icons.description_outlined
                  : Icons.account_balance_wallet_outlined,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (!isRead) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context, notification.titleKey, notification.params,
                        ),
                        style: isRead
                            ? theme.textTheme.titleSmall
                            : theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context, age.key, age.params),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(
                    context, notification.bodyKey, notification.params,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (user.isAdmin)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: theme.colorScheme.onSurface.withOpacity(0.45),
              ),
              tooltip: AppLocalizations.of(context, 'delete'),
              onPressed: () => _delete(context, ref),
            ),
        ],
      ),
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
