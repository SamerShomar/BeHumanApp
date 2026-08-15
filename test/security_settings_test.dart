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

    test('a launch is given long enough to get past its first queries', () {
      // The crash this recovers from happens while the first screen queries
      // load, which is after the first frame — so the marker must outlive it.
      expect(FirestoreCacheGuard.settleDelay.inSeconds, greaterThanOrEqualTo(10));
    });
  });
}
