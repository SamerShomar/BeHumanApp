import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:be_human_app/core/config/app_config.dart';
import 'package:be_human_app/core/services/file_storage_service.dart';

void main() {
  group('AppConfig', () {
    test('reports storage as unconfigured when no keys were passed', () {
      // The test runner supplies no --dart-define values, so this doubles as a
      // guard that no key was ever hardcoded as a default.
      expect(AppConfig.supabaseUrl, isEmpty);
      expect(AppConfig.supabaseAnonKey, isEmpty);
      expect(AppConfig.isStorageConfigured, isFalse);
    });

    test('falls back to the default bucket name', () {
      expect(AppConfig.proposalsBucket, 'proposals');
    });
  });

  group('FileStorageService without a client', () {
    // A build with no storage keys must fail with a readable message at the
    // point of use rather than crashing on a null client.
    final service = FileStorageService(client: null);

    test('uploading throws a FileStorageException', () {
      expect(
        () => service.uploadProposalPdf(
          proposalId: 'p1',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<FileStorageException>()),
      );
    });

    test('signing a URL throws a FileStorageException', () {
      expect(
        () => service.createSignedUrl('p1.pdf'),
        throwsA(isA<FileStorageException>()),
      );
    });

    test('deleting throws a FileStorageException', () {
      expect(
        () => service.deleteFile('p1.pdf'),
        throwsA(isA<FileStorageException>()),
      );
    });

    test('the exception message is human readable, not a stack trace', () {
      const exception = FileStorageException('فشل رفع الملف');
      expect(exception.toString(), 'فشل رفع الملف');
    });
  });
}
