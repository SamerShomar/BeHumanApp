import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:be_human_app/core/config/app_config.dart';
import 'package:be_human_app/core/domain/attachment.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';

/// Raised when a file cannot be stored or read back.
///
/// Carries a translation key rather than a finished sentence: these are thrown
/// deep in a service with no BuildContext, and the app is used in three
/// languages. Call `localized(context)` where the failure is shown.
class FileStorageException implements Exception {
  const FileStorageException(this.messageKey, {this.params});

  final String messageKey;
  final Map<String, String>? params;

  /// Untranslated, for logs and test names — never for the UI.
  @override
  String toString() => messageKey;
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

  /// Ceiling on any single storage call. Without it a stalled connection —
  /// common on the networks this app runs over — leaves the upload spinner
  /// on screen with no way out.
  static const _timeout = Duration(seconds: 60);

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) {
      throw const FileStorageException('storage_not_configured');
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
  ///
  /// The extension is kept: a transfer notice is as often a photo as a scan,
  /// and the stored object has to say which it is — both the signed link and
  /// the in-app viewer decide what to do from it.
  Future<String> uploadInvoiceAttachment({
    required String transactionId,
    required Uint8List bytes,
    required String fileName,
  }) {
    final ext = Attachment.extensionOf(fileName);
    return _upload(
      'invoices/$transactionId${ext.isEmpty ? '' : '.$ext'}',
      bytes,
      contentType: Attachment.contentTypeOf(fileName),
    );
  }

  /// Uploads a file into a user-created archive folder.
  Future<String> uploadArchiveDocument({
    required String folderId,
    required String documentId,
    required String fileName,
    required List<int> bytes,
  }) {
    final ext = Attachment.extensionOf(fileName);
    return _upload(
      'archive/$folderId/$documentId${ext.isEmpty ? '' : '.$ext'}',
      Uint8List.fromList(bytes),
      contentType: Attachment.contentTypeOf(fileName),
    );
  }

  /// Fetches a stored file's bytes directly, for saving or sharing rather
  /// than viewing. Separate from [createSignedUrl]: a signed URL is for
  /// something that renders it (the PDF viewer); this is for handing raw
  /// bytes to the share sheet.
  Future<Uint8List> downloadBytes(String path) async {
    try {
      return await _requireClient.storage.from(_bucket).download(path).timeout(_timeout);
    } on TimeoutException {
      throw const FileStorageException('download_timeout');
    } on StorageException catch (e) {
      throw _describe(e);
    }
  }

  /// Uploads a profile picture and returns its object path.
  ///
  /// Keyed by uid so a new picture replaces the old one instead of leaving the
  /// previous file orphaned in the bucket.
  Future<String> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    required String contentType,
  }) {
    return _upload('avatars/$uid', bytes, contentType: contentType);
  }

  Future<String> _upload(
    String path,
    Uint8List bytes, {
    String contentType = 'application/pdf',
  }) async {
    try {
      await _requireClient.storage
          .from(_bucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          )
          .timeout(_timeout);
      return path;
    } on TimeoutException {
      throw const FileStorageException('upload_timeout');
    } on StorageException catch (e) {
      throw _describe(e);
    }
  }

  /// Visible for testing the mapping without a live Supabase.
  @visibleForTesting
  FileStorageException describeForTest(StorageException e) => _describe(e);

  /// Turns Supabase's terse errors into something the person holding the phone
  /// can act on. "Bucket not found" in particular means a setup step was
  /// missed, not that anything is wrong with the file.
  FileStorageException _describe(StorageException e) {
    final message = e.message.toLowerCase();

    if (message.contains('bucket not found')) {
      return FileStorageException('bucket_missing', params: {'bucket': _bucket});
    }
    if (message.contains('row-level security') || message.contains('unauthorized')) {
      return FileStorageException('storage_no_permission', params: {'bucket': _bucket});
    }
    if (message.contains('exceeded') || message.contains('too large')) {
      return const FileStorageException('file_too_large_remote');
    }
    return FileStorageException('upload_failed', params: {'error': e.message});
  }

  /// Returns a temporary URL for reading [path].
  ///
  /// The bucket is private, so this is what makes the file viewable. The link
  /// stops working once [expiresIn] elapses, which keeps a copied link from
  /// outliving the session that produced it.
  Future<String> createSignedUrl(
    String path, {
    Duration expiresIn = const Duration(minutes: 5),
  }) async {
    try {
      return await _requireClient.storage
          .from(_bucket)
          .createSignedUrl(path, expiresIn.inSeconds)
          .timeout(_timeout);
    } on TimeoutException {
      throw const FileStorageException('open_timeout');
    } on StorageException catch (e) {
      throw _describe(e);
    }
  }

  /// Removes a stored object, whatever kind it is.
  Future<void> deleteFile(String path) async {
    try {
      await _requireClient.storage.from(_bucket).remove([path]).timeout(_timeout);
    } on TimeoutException {
      throw const FileStorageException('delete_timeout');
    } on StorageException catch (e) {
      throw FileStorageException('delete_failed', params: {'error': e.message});
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

/// Renders a storage failure in the reader's language.
///
/// Kept as an extension so the service itself stays free of widget imports.
extension FileStorageExceptionL10n on FileStorageException {
  String localized(BuildContext context) =>
      AppLocalizations.of(context, messageKey, params);
}
