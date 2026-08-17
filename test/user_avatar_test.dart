import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/widgets/user_avatar.dart';

void main() {
  Widget wrap(Widget child) => ProviderScope(
        child: MaterialApp(home: Scaffold(body: child)),
      );

  group('UserAvatar initials', () {
    testWidgets('uses the first letter of the first two names', (tester) async {
      await tester.pumpWidget(
        wrap(const UserAvatar(photoPath: null, name: 'Samer Shomar')),
      );
      expect(find.text('SS'), findsOneWidget);
    });

    testWidgets('handles a single name', (tester) async {
      await tester.pumpWidget(
        wrap(const UserAvatar(photoPath: null, name: 'Foekje')),
      );
      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('handles Arabic names', (tester) async {
      await tester.pumpWidget(
        wrap(const UserAvatar(photoPath: null, name: 'محمود أبو عيشة')),
      );
      expect(find.text('مأ'), findsOneWidget);
    });

    testWidgets('falls back to a placeholder for an empty name', (tester) async {
      await tester.pumpWidget(
        wrap(const UserAvatar(photoPath: null, name: '   ')),
      );
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('AppUser.photoPath', () {
    test('round-trips through JSON', () {
      const user = AppUser(
        uid: 'u1',
        email: 'a@b.org',
        name: 'A B',
        role: UserRole.member,
        team: UserTeam.gaza,
        photoPath: 'avatars/u1',
      );

      final json = user.toJson();
      // Stored as a bare object path, not a URL — the bucket is private and a
      // viewable link is minted on demand.
      expect(json['photoPath'], 'avatars/u1');

      expect(AppUser.fromJson(json).photoPath, 'avatars/u1');
    });

    test('is optional', () {
      final user = AppUser.fromJson(const {
        'uid': 'u1',
        'email': 'a@b.org',
        'name': 'A B',
        'role': 'member',
        'team': 'gaza',
      });
      expect(user.photoPath, isNull);
    });
  });
}
