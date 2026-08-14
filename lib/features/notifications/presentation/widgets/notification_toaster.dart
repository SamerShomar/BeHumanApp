import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/notifications/domain/app_notification.dart';
import 'package:be_human_app/features/notifications/presentation/providers/notification_providers.dart';

/// Shows an alert the moment a notification arrives while the app is open.
///
/// This is what makes the feature feel like a notification rather than a list
/// you have to remember to check. It only covers a running app — an alert on a
/// closed phone needs a server to send it, which the free Firebase plan does
/// not include; see `docs/notifications.md`.
class NotificationToaster extends ConsumerStatefulWidget {
  const NotificationToaster({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationToaster> createState() => _NotificationToasterState();
}

class _NotificationToasterState extends ConsumerState<NotificationToaster> {
  /// Only events that happen after the app opens are announced. Without this,
  /// the first emission of the feed would replay everything that arrived while
  /// the phone was closed, all at once.
  late final DateTime _openedAt = DateTime.now();

  /// Guards against announcing the same event twice when the feed re-emits —
  /// which it does every time anyone marks something read.
  String? _announcedId;

  @override
  Widget build(BuildContext context) {
    ref.listen<List<AppNotification>>(myNotificationsProvider, (previous, next) {
      if (next.isEmpty) return;

      final newest = next.first;
      if (newest.id == _announcedId) return;
      if (!newest.createdAt.isAfter(_openedAt)) return;

      _announcedId = newest.id;
      _announce(newest);
    });

    return widget.child;
  }

  void _announce(AppNotification notification) {
    final messenger = ScaffoldMessenger.of(context);
    final route = notification.route;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context, notification.titleKey, notification.params),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              AppLocalizations.of(context, notification.bodyKey, notification.params),
            ),
          ],
        ),
        action: route == null
            ? null
            : SnackBarAction(
                label: AppLocalizations.of(context, 'open'),
                onPressed: () => context.go(route),
              ),
      ),
    );
  }
}
