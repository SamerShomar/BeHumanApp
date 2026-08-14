import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/notifications/domain/app_notification.dart';
import 'package:be_human_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:be_human_app/features/notifications/presentation/widgets/notification_toaster.dart';

void main() {
  const reviewer = AppUser(
    uid: 'reviewer',
    email: 'r@behuman.org',
    name: 'Reviewer',
    role: UserRole.manager,
    team: UserTeam.netherlands,
  );

  AppNotification notification({
    required String id,
    required DateTime createdAt,
    String actorUid = 'gaza-1',
  }) =>
      AppNotification(
        id: id,
        type: NotificationType.proposal,
        titleKey: 'notification_proposal_title',
        bodyKey: 'notification_proposal_body',
        params: const {'name': 'Mahmoud', 'title': 'Water'},
        audience: NotificationAudience.reviewers,
        actorUid: actorUid,
        createdAt: createdAt,
        route: '/proposals',
      );

  Future<StreamController<List<AppNotification>>> pump(WidgetTester tester) async {
    final controller = StreamController<List<AppNotification>>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserStreamProvider.overrideWith((ref) => Stream.value(reviewer)),
          notificationFeedProvider.overrideWith((ref) => controller.stream),
        ],
        child: const MaterialApp(
          home: Scaffold(body: NotificationToaster(child: SizedBox())),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  testWidgets('stays silent for events that predate opening the app', (tester) async {
    final controller = await pump(tester);

    // The backlog a user comes back to. Replaying it as pop-ups would bury
    // the screen they actually opened.
    controller.add([
      notification(id: 'old', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
    ]);
    await tester.pump();

    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('announces an event that arrives while the app is open', (tester) async {
    final controller = await pump(tester);

    controller.add([
      notification(id: 'new', createdAt: DateTime.now().add(const Duration(seconds: 1))),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('New proposal'), findsOneWidget);
  });

  testWidgets('does not announce the same event twice', (tester) async {
    final controller = await pump(tester);
    final fresh = notification(
      id: 'new',
      createdAt: DateTime.now().add(const Duration(seconds: 1)),
    );

    controller.add([fresh]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Marking anything read re-emits the whole feed; the alert must not
    // reappear each time.
    controller.add([fresh]);
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('says nothing about the user\'s own action', (tester) async {
    final controller = await pump(tester);

    controller.add([
      notification(
        id: 'mine',
        createdAt: DateTime.now().add(const Duration(seconds: 1)),
        actorUid: reviewer.uid,
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(SnackBar), findsNothing);
  });
}
