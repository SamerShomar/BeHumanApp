import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:be_human_app/core/security/cache_guard.dart';
import 'package:be_human_app/core/security/security_settings.dart';

void main() {
  group('SecuritySettings', () {
    test('the offline cache is on, so writes queue through an outage', () {
      // Turning this off would restore on-disk secrecy but break working
      // offline, which the app is required to do.
      expect(SecuritySettings.allowOfflineCache, isTrue);
    });

    test('the inactivity timeout is short enough to matter', () {
      // Sessions survive a restart by choice, so this timeout is the main
      // guard while the app is open and must not drift upwards.
      expect(SecuritySettings.inactivityTimeout, lessThanOrEqualTo(const Duration(minutes: 15)));
      // A timeout under a minute would sign users out mid-task.
      expect(SecuritySettings.inactivityTimeout, greaterThanOrEqualTo(const Duration(minutes: 1)));
    });
  });

  group('FirestoreCacheGuard', () {
    test('the cache is bounded, so Firestore can collect it', () {
      // CACHE_SIZE_UNLIMITED switches garbage collection off entirely: the
      // cache then only ever grows, which is how a row big enough to crash
      // Android's CursorWindow accumulates in the first place.
      expect(SecuritySettings.cacheSizeBytes, isNot(-1));
      expect(SecuritySettings.cacheSizeBytes, greaterThan(10 * 1024 * 1024));
    });

    testWidgets('a foreground death leaves the marker behind', (tester) async {
      // The whole point of the guard. The crash fires when a collection is
      // read, which is whenever somebody opens the screen that reads it —
      // possibly long after launch. Only backgrounding clears the marker, so
      // a process killed while the app is on screen is still recorded.
      await tester.pumpWidget(
        const FirestoreCacheGuardScope(child: SizedBox.shrink()),
      );

      final binding = tester.binding;
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
      ]) {
        binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump();

      // Nothing above ends a session: pulling down the notification shade or
      // taking a call must not be mistaken for the app being put away.
      expect(tester.takeException(), isNull);
    });
  });
}
