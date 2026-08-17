import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/notifications/domain/app_notification.dart';
import 'package:be_human_app/features/notifications/domain/relative_time.dart';
import 'package:be_human_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:be_human_app/features/notifications/presentation/widgets/notification_bell.dart';

AppUser _user({
  String uid = 'u1',
  UserRole role = UserRole.member,
  UserTeam team = UserTeam.gaza,
}) =>
    AppUser(uid: uid, email: '$uid@behuman.org', name: uid, role: role, team: team);

AppNotification _notification({
  String id = 'n1',
  String audience = NotificationAudience.all,
  String actorUid = 'someone-else',
  List<String> readBy = const [],
}) =>
    AppNotification(
      id: id,
      type: NotificationType.proposal,
      titleKey: 'notification_proposal_title',
      bodyKey: 'notification_proposal_body',
      params: const {'name': 'Samer', 'title': 'Water project'},
      audience: audience,
      actorUid: actorUid,
      createdAt: DateTime(2026, 1, 1),
      route: '/proposals',
      readBy: readBy,
    );

void main() {
  group('AppNotification.isVisibleTo', () {
    test('never shows a user their own action', () {
      final notification = _notification(actorUid: 'u1');
      expect(notification.isVisibleTo(_user(uid: 'u1')), isFalse);
      expect(notification.isVisibleTo(_user(uid: 'u2')), isTrue);
    });

    test('a reviewers-only event reaches managers and admins, not members', () {
      final notification = _notification(audience: NotificationAudience.reviewers);

      expect(notification.isVisibleTo(_user(role: UserRole.admin)), isTrue);
      expect(notification.isVisibleTo(_user(role: UserRole.manager)), isTrue);
      expect(notification.isVisibleTo(_user(role: UserRole.member)), isFalse);
    });

    test('an "all" event reaches every role', () {
      final notification = _notification();
      for (final role in UserRole.values) {
        expect(notification.isVisibleTo(_user(role: role)), isTrue);
      }
    });

    test('an unrecognised audience is shown to nobody', () {
      // Fewest recipients rather than most: an unsendable notification beats
      // one that leaks to the wrong people.
      final notification = _notification(audience: 'accountants');
      for (final role in UserRole.values) {
        expect(notification.isVisibleTo(_user(role: role)), isFalse);
      }
    });
  });

  group('AppNotification serialization', () {
    test('round-trips', () {
      final original = _notification(readBy: const ['u2', 'u3']);
      final restored = AppNotification.fromJson(original.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, original.id);
      expect(restored.audience, original.audience);
      expect(restored.params['title'], 'Water project');
      expect(restored.readBy, ['u2', 'u3']);
      expect(restored.createdAt, original.createdAt);
      expect(restored.route, '/proposals');
    });

    test('rejects a document with no id or an unparseable date', () {
      expect(AppNotification.fromJson({'createdAt': '2026-01-01T00:00:00.000'}), isNull);
      expect(AppNotification.fromJson({'id': 'n1', 'createdAt': 'yesterday'}), isNull);
    });

    test('survives missing and wrongly typed fields', () {
      // Documents written by an older build, or hand-edited in the console,
      // must not blank the whole feed.
      final restored = AppNotification.fromJson({
        'id': 'n1',
        'createdAt': '2026-01-01T00:00:00.000',
        'params': {'amount': 12},
        'readBy': ['u2', 7],
      });

      expect(restored, isNotNull);
      expect(restored!.params['amount'], '12');
      expect(restored.readBy, ['u2']);
      expect(restored.audience, NotificationAudience.all);
    });
  });

  group('read state', () {
    test('tracks who has seen it', () {
      final notification = _notification(readBy: const ['u2']);
      expect(notification.isReadBy('u2'), isTrue);
      expect(notification.isReadBy('u1'), isFalse);
    });
  });

  group('RelativeTime', () {
    final now = DateTime(2026, 6, 1, 12, 0);

    test('describes recent, minutes, hours and days', () {
      expect(RelativeTime.describe(now.subtract(const Duration(seconds: 20)), now: now).key,
          'time_just_now');
      expect(RelativeTime.describe(now.subtract(const Duration(minutes: 5)), now: now).key,
          'time_minutes_ago');
      expect(RelativeTime.describe(now.subtract(const Duration(hours: 3)), now: now).key,
          'time_hours_ago');
      expect(RelativeTime.describe(now.subtract(const Duration(days: 4)), now: now).key,
          'time_days_ago');
    });

    test('carries the count as a parameter', () {
      final result = RelativeTime.describe(now.subtract(const Duration(minutes: 42)), now: now);
      expect(result.params['n'], '42');
    });

    test('treats a future timestamp as just now', () {
      // Two phones with slightly different clocks would otherwise produce
      // "in -2 minutes".
      expect(RelativeTime.describe(now.add(const Duration(minutes: 5)), now: now).key,
          'time_just_now');
    });

    test('every key it can return is translated in all languages', () {
      for (final key in ['time_just_now', 'time_minutes_ago', 'time_hours_ago', 'time_days_ago']) {
        for (final locale in AppLocalizations.supportedLocales) {
          expect(AppLocalizations.translate(locale, key), isNot(key));
        }
      }
    });
  });

  group('NotificationBell', () {
    Widget wrap(int unread) => ProviderScope(
          overrides: [
            unreadNotificationCountProvider.overrideWith((ref) => unread),
          ],
          child: const MaterialApp(
            home: Scaffold(body: NotificationBell()),
          ),
        );

    testWidgets('shows no badge when everything is read', (tester) async {
      await tester.pumpWidget(wrap(0));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows the unread count', (tester) async {
      await tester.pumpWidget(wrap(3));
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('caps the badge so it cannot stretch the app bar', (tester) async {
      await tester.pumpWidget(wrap(250));
      expect(find.text('99+'), findsOneWidget);
    });
  });
}
