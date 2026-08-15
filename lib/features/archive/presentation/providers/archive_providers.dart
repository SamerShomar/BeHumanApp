import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/core/providers/auth_state_provider.dart';

import 'package:be_human_app/core/services/file_storage_service.dart';
import 'package:be_human_app/features/archive/domain/archive_models.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';

/// Folders a user has created directly in the archive. The two system
/// folders (proposals, invoices) are not stored here — they are derived from
/// the proposals and transactions collections and shown alongside these.
final archiveFoldersProvider = StreamProvider<List<ArchiveFolder>>((ref) {
  if (ref.watch(signedInUidProvider) == null) return Stream.value(const []);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore.collection('archive_folders').orderBy('name').snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => ArchiveFolder.fromJson({'id': doc.id, ...doc.data()}))
            .toList(),
      );
});

/// Documents inside one user-created folder.
///
/// Filtered on the server, sorted here. Firestore needs a composite index for
/// a `where` and an `orderBy` on different fields, and without it the query
/// does not return empty — it fails, which is why every folder anyone opened
/// showed an error instead of its (usually empty) contents. Sorting a single
/// folder's documents in Dart costs nothing and needs no index to exist.
final archiveDocumentsProvider =
    StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, folderId) {
  if (ref.watch(signedInUidProvider) == null) return Stream.value(const []);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('archive_documents')
      .where('folderId', isEqualTo: folderId)
      .snapshots()
      .map((snapshot) {
    final docs = snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList()
      ..sort((a, b) {
        // Newest first. A document with no date sorts last rather than
        // throwing the whole list into an error.
        final left = '${a['date'] ?? ''}';
        final right = '${b['date'] ?? ''}';
        return right.compareTo(left);
      });
    return docs;
  });
});

/// Creates and removes folders and documents in the archive.
///
/// Every signed-in member may organise the archive — there is no owner check
/// here, matching how the feature was scoped. Firestore rules mirror that:
/// anyone with a profile may write to these two collections.
class ArchiveService {
  ArchiveService(this._firestore, this._storage);

  final FirebaseFirestore _firestore;
  final FileStorageService _storage;

  Future<void> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final id = 'f${DateTime.now().millisecondsSinceEpoch}';
    await _firestore.collection('archive_folders').doc(id).set({
      'id': id,
      'name': trimmed,
    });
  }

  /// Deletes a folder along with everything in it.
  ///
  /// Firestore has no cascading delete, so each document's stored file and
  /// record are removed first, then the folder itself. A file that fails to
  /// delete does not block the rest — an orphaned object in the bucket is
  /// preferable to a folder that cannot be removed.
  Future<void> deleteFolder(String folderId) async {
    final docs = await _firestore
        .collection('archive_documents')
        .where('folderId', isEqualTo: folderId)
        .get();

    for (final doc in docs.docs) {
      final path = doc.data()['storagePath'];
      if (path is String) {
        try {
          await _storage.deleteFile(path);
        } on FileStorageException {
          // See note above.
        }
      }
      await doc.reference.delete();
    }

    await _firestore.collection('archive_folders').doc(folderId).delete();
  }

  Future<void> addDocument({
    required String folderId,
    required String fileName,
    required List<int> bytes,
    required String uploaderUid,
    required String uploaderName,
  }) async {
    final id = 'd${DateTime.now().millisecondsSinceEpoch}';
    final storagePath = await _storage.uploadArchiveDocument(
      folderId: folderId,
      documentId: id,
      fileName: fileName,
      bytes: bytes,
    );

    await _firestore.collection('archive_documents').doc(id).set({
      'id': id,
      'folderId': folderId,
      'fileName': fileName,
      'storagePath': storagePath,
      'uploadedBy': uploaderUid,
      'uploadedByName': uploaderName,
      'date': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteDocument(String documentId, String? storagePath) async {
    if (storagePath != null) {
      try {
        await _storage.deleteFile(storagePath);
      } on FileStorageException {
        // The record is what matters; a leftover file is acceptable.
      }
    }
    await _firestore.collection('archive_documents').doc(documentId).delete();
  }
}

final archiveServiceProvider = Provider<ArchiveService>(
  (ref) => ArchiveService(
    ref.watch(firebaseFirestoreProvider),
    ref.watch(fileStorageServiceProvider),
  ),
);
