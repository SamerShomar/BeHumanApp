import 'package:flutter_test/flutter_test.dart';
import 'package:be_human_app/features/archive/presentation/widgets/archive_actions.dart';

void main() {
  group('looksLikePdf', () {
    test('recognises the extension case-insensitively', () {
      expect(looksLikePdf('report.pdf'), isTrue);
      expect(looksLikePdf('report.PDF'), isTrue);
      expect(looksLikePdf('REPORT.Pdf'), isTrue);
    });

    test('rejects other file types', () {
      // These cannot be previewed in-app — only downloaded — since the app
      // has no viewer for them.
      expect(looksLikePdf('scan.jpg'), isFalse);
      expect(looksLikePdf('contract.docx'), isFalse);
      expect(looksLikePdf('notes.txt'), isFalse);
      expect(looksLikePdf('no-extension'), isFalse);
    });
  });
}
