import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/core/services/push_registrar.dart';
import 'package:be_human_app/core/services/push_service.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';

void main() {
  const user = AppUser(
    uid: 'u1',
    email: 'u1@behuman.org',
    name: 'Samer',
    role: UserRole.admin,
    team: UserTeam.netherlands,
  );

  testWidgets('keeps the app running when push is unavailable', (tester) async {
    // No Firebase in a test binding, so building the push service throws.
    // That must degrade to in-app notifications, not take the app down — the
    // same thing happens on a phone with no Google Play services.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserStreamProvider.overrideWith((ref) => Stream.value(user)),
        ],
        child: const MaterialApp(
          home: PushRegistrar(child: Text('app', textDirection: TextDirection.ltr)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('app'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders its child unchanged when nobody is signed in', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(
          home: PushRegistrar(child: Text('app', textDirection: TextDirection.ltr)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('app'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('the route a tapped notification opens', () {
    test('is honoured when the app has that screen', () {
      // The two the sender actually uses.
      expect(PushService.routeFrom({'route': '/proposals'}), '/proposals');
      expect(PushService.routeFrom({'route': '/financial'}), '/financial');
    });

    test('is dropped when it is anything else', () {
      // The payload comes from outside the app. Handing the router an
      // arbitrary string lands the user on the error screen, and a
      // notification that breaks the app when tapped is worse than one that
      // merely opens it.
      expect(PushService.routeFrom({'route': '/nope'}), isNull);
      expect(PushService.routeFrom({'route': 'https://example.com'}), isNull);
      expect(PushService.routeFrom({'route': ''}), isNull);
      expect(PushService.routeFrom({'route': 42}), isNull);
      expect(PushService.routeFrom(const {}), isNull);
    });

    test('covers every destination the shell can reach', () {
      // If a tab is added to the app and not added here, notifications
      // pointing at it stop navigating — silently, since the route is simply
      // dropped. This fails instead.
      for (final route in [
        '/home',
        '/proposals',
        '/financial',
        '/archive',
        '/dashboard',
        '/settings',
        '/notifications',
      ]) {
        expect(PushService.knownRoutes, contains(route), reason: route);
      }
    });
  });
}
