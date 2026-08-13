import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:be_human_app/core/config/app_config.dart';

/// Raised when a file cannot be stored or read back. Carries a message that is
/// safe to show to the user.
class FileStorageException implements Exception {
  const FileStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Stores proposal PDFs in Supabase Storage.
///
/// Firestore caps a document at 1 MiB, so the PDF bytes cannot live in the
/// document itself. Only the object path is written to Firestore; the bytes go
/// to a private bucket and are read back through a short-lived signed URL.
class FileStorageService {
  FileStorageService({SupabaseClient? client, String? bucket})
      : _client = client,
        _bucket = bucket ?? AppConfig.proposalsBucket;

  final SupabaseClient? _client;
  final String _bucket;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) {
      throw const FileStorageException(
        'خدمة تخزين الملفات غير مُهيّأة في هذه النسخة من التطبيق',
      );
    }
    return client;
  }

  /// Uploads [bytes] and returns the object path to persist in Firestore.
  ///
  /// The path is derived from [proposalId] so re-uploading for the same
  /// proposal replaces the previous file instead of orphaning it.
  Future<String> uploadProposalPdf({
    required String proposalId,
    required Uint8List bytes,
  }) {
    return _upload('$proposalId.pdf', bytes);
  }

  /// Invoices share the bucket but live under their own prefix, so a listing
  /// or a policy can target one kind of document without the other.
  Future<String> uploadInvoicePdf({
    required String transactionId,
    required Uint8List bytes,
  }) {
    return _upload('invoices/$transactionId.pdf', bytes);
  }

  Future<String> _upload(String path, Uint8List bytes) async {
    try {
      await _requireClient.storage.from(_bucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );
      return path;
    } on StorageException catch (e) {
      throw FileStorageException('فشل رفع الملف: ${e.message}');
    }
  }

  /// Returns a temporary URL for reading [path].
  ///
  /// The bucket is private, so this is what makes the file viewable. The link
  /// stops working once [expiresIn] elapses, which keeps it from being shared
  /// outside the app indefinitely.
  Future<String> createSignedUrl(
    String path, {
    Duration expiresIn = const Duration(hours: 1),
  }) async {
    try {
      return await _requireClient.storage
          .from(_bucket)
          .createSignedUrl(path, expiresIn.inSeconds);
    } on StorageException catch (e) {
      throw FileStorageException('فشل فتح الملف: ${e.message}');
    }
  }

  Future<void> deleteProposalPdf(String path) async {
    try {
      await _requireClient.storage.from(_bucket).remove([path]);
    } on StorageException catch (e) {
      throw FileStorageException('فشل حذف الملف: ${e.message}');
    }
  }
}

/// Null until [AppConfig.isStorageConfigured], so a build without storage keys
/// still starts and fails only at the point of use.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!AppConfig.isStorageConfigured) return null;
  return Supabase.instance.client;
});

final fileStorageServiceProvider = Provider<FileStorageService>((ref) {
  return FileStorageService(client: ref.watch(supabaseClientProvider));
});
