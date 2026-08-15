import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/projects/domain/project.dart';

/// How many projects the home screen keeps in memory. The section shows fewer
/// than this; the rest are there so "see all" has something to open later.
const int projectFeedLimit = 20;

/// The foundation's projects, newest first.
final projectsProvider = StreamProvider<List<Project>>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('projects')
      .orderBy('date', descending: true)
      .limit(projectFeedLimit)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Project.fromJson({'id': doc.id, ...doc.data()}))
          // One malformed document must not blank the whole section.
          .whereType<Project>()
          .toList());
});

/// The site's own words about the organisation.
///
/// Stored as a single document rather than held in memory: the previous
/// version kept it in a StateNotifier, so whatever an admin pulled from the
/// website was gone on the next launch and no other user ever saw it.
final siteContentProvider =
    StreamProvider<Map<String, String>>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore.collection('site_content').doc('about').snapshots().map(
        (doc) => {
          for (final entry in (doc.data() ?? const {}).entries)
            entry.key: '${entry.value ?? ''}',
        },
      );
});

/// Writes projects and site content. Firestore rules restrict all of this to
/// admins, so the UI gating is a convenience rather than the boundary.
class ProjectService {
  ProjectService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('projects');

  Future<void> save(Project project) =>
      _collection.doc(project.id).set(project.toJson());

  Future<void> delete(String id) => _collection.doc(id).delete();

  /// Replaces the imported set with what the website currently says.
  ///
  /// Projects added by hand are left alone — only ones carrying a
  /// `sourceUrl`, meaning a previous import put them there, are replaced. An
  /// import must never quietly delete something a person typed.
  Future<int> replaceImported(List<Project> imported) async {
    if (imported.isEmpty) return 0;

    final existing = await _collection.where('sourceUrl', isNull: false).get();

    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final project in imported) {
      batch.set(_collection.doc(project.id), project.toJson());
    }
    await batch.commit();

    return imported.length;
  }

  Future<void> saveSiteContent(Map<String, String> content) =>
      _firestore.collection('site_content').doc('about').set(
            content,
            SetOptions(merge: true),
          );
}

final projectServiceProvider = Provider<ProjectService>(
  (ref) => ProjectService(ref.watch(firebaseFirestoreProvider)),
);
