import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/notifications/presentation/providers/notification_providers.dart';

/// The bell shown in every screen's app bar, with an unread count.
///
/// It renders nothing at all when there is no signed-in profile, so it is safe
/// to place unconditionally.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationCountProvider);
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: AppLocalizations.of(context, 'notifications'),
      // `push`, not `go`: the feed sits on top of the screen you came from and
      // the app bar gets a working back button, instead of replacing it.
      onPressed: () => context.push('/notifications'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (unread > 0)
            // The badge hangs off the trailing edge, which is the left in
            // Arabic — `end` follows the reading direction, `right` does not.
            PositionedDirectional(
              top: -4,
              end: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: scheme.error,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
