import 'package:flutter_test/flutter_test.dart';
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
}
