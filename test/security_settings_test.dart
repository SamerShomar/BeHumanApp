import 'package:flutter_test/flutter_test.dart';
import 'package:be_human_app/core/security/security_settings.dart';

void main() {
  group('SecuritySettings', () {
    test('the offline cache stays disabled', () {
      // Firestore's on-disk cache is unencrypted, so enabling it puts every
      // viewed proposal and transaction in plaintext on the device. Flipping
      // this is a deliberate decision, not an incidental edit.
      expect(SecuritySettings.allowOfflineCache, isFalse);
    });

    test('the inactivity timeout is short enough to matter', () {
      expect(SecuritySettings.inactivityTimeout, lessThanOrEqualTo(const Duration(minutes: 15)));
      // A timeout under a minute would sign users out mid-task.
      expect(SecuritySettings.inactivityTimeout, greaterThanOrEqualTo(const Duration(minutes: 1)));
    });
  });
}
