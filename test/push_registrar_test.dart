import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/core/services/push_registrar.dart';
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
}
