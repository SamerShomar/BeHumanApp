import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    test('toString exposes the key, for logs rather than the UI', () {
      const exception = FileStorageException('upload_failed');
      expect(exception.toString(), 'upload_failed');
    });
  });

  group('storage error messages', () {
    // "Bucket not found" means a setup step was missed. Passing Supabase's
    // wording straight through leaves the user with nothing to act on.
    final service = FileStorageService(client: null, bucket: 'proposals');

    FileStorageException describe(String supabaseMessage) =>
        service.describeForTest(StorageException(supabaseMessage, statusCode: '400'));

    test('names the missing bucket, carrying it as a parameter', () {
      // The key is translated at the point of display, so the bucket name
      // travels alongside it rather than baked into a sentence.
      final failure = describe('Bucket not found');
      expect(failure.messageKey, 'bucket_missing');
      expect(failure.params?['bucket'], 'proposals');
    });

    test('points at policies when the write is refused', () {
      expect(
        describe('new row violates row-level security policy').messageKey,
        'storage_no_permission',
      );
    });

    test('passes an unrecognised failure through as a parameter', () {
      final failure = describe('some novel failure');
      expect(failure.messageKey, 'upload_failed');
      expect(failure.params?['error'], 'some novel failure');
    });
  });
}
