import 'package:flutter_test/flutter_test.dart';
import 'package:be_human_app/features/archive/domain/archive_models.dart';

void main() {
  group('ArchiveFolder', () {
    test('the two system folder ids cannot collide with a Firestore id', () {
      // User folder ids are 'f<timestamp>' (see ArchiveService.createFolder),
      // so the leading double underscore keeps the reserved ids out of that
      // space by construction, not by convention alone.
      expect(ArchiveFolder.proposalsId, startsWith('__'));
      expect(ArchiveFolder.invoicesId, startsWith('__'));
      expect(ArchiveFolder.proposalsId, isNot(ArchiveFolder.invoicesId));
    });

    test('fromJson always produces a non-system folder', () {
      // Every document actually stored in Firestore is a user folder — the
      // two system ones are synthesised in the UI and never round-trip
      // through fromJson/toJson.
      final folder = ArchiveFolder.fromJson({'id': 'f123', 'name': 'العقود'});
      expect(folder.id, 'f123');
      expect(folder.name, 'العقود');
      expect(folder.isSystem, isFalse);
    });

    test('fromJson tolerates a missing name rather than throwing', () {
      final folder = ArchiveFolder.fromJson({'id': 'f123'});
      expect(folder.name, '');
    });

    test('toJson round-trips id and name', () {
      const folder = ArchiveFolder(id: 'f123', name: 'العقود', isSystem: false);
      final json = folder.toJson();
      expect(json, {'id': 'f123', 'name': 'العقود'});
    });
  });

  group('ArchiveEntry', () {
    test('is openable only when a storage path is present', () {
      const withPath = ArchiveEntry(fileName: 'a.pdf', storagePath: 'x/a.pdf');
      const withoutPath = ArchiveEntry(fileName: 'a.pdf', storagePath: null);

      expect(withPath.isOpenable, isTrue);
      expect(withoutPath.isOpenable, isFalse);
    });
  });
}
