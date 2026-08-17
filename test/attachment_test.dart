import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/core/domain/attachment.dart';

void main() {
  group('kindOf', () {
    test('recognises a scan case-insensitively', () {
      expect(Attachment.kindOf('report.pdf'), AttachmentKind.pdf);
      expect(Attachment.kindOf('report.PDF'), AttachmentKind.pdf);
      expect(Attachment.kindOf('REPORT.Pdf'), AttachmentKind.pdf);
    });

    test('recognises a photograph', () {
      // The common case for a transfer notice: someone photographs the slip
      // or screenshots the banking app. Rejecting these is what made the
      // picker useless for the people actually recording payments.
      expect(Attachment.kindOf('receipt.jpg'), AttachmentKind.image);
      expect(Attachment.kindOf('receipt.JPEG'), AttachmentKind.image);
      expect(Attachment.kindOf('screenshot.png'), AttachmentKind.image);
      expect(Attachment.kindOf('IMG_0042.HEIC'), AttachmentKind.image);
      expect(Attachment.kindOf('photo.webp'), AttachmentKind.image);
    });

    test('rejects anything with no viewer behind it', () {
      expect(Attachment.kindOf('contract.docx'), AttachmentKind.other);
      expect(Attachment.kindOf('notes.txt'), AttachmentKind.other);
      expect(Attachment.kindOf('no-extension'), AttachmentKind.other);
      expect(Attachment.kindOf('trailing.'), AttachmentKind.other);
    });

    test('reads the last extension, not the first', () {
      // "invoice.pdf.jpg" is a photograph of a printed invoice, and treating
      // it as a PDF hands the wrong viewer a JPEG.
      expect(Attachment.kindOf('invoice.pdf.jpg'), AttachmentKind.image);
      expect(Attachment.kindOf('scan.jpg.pdf'), AttachmentKind.pdf);
    });
  });

  group('contentTypeOf', () {
    test('matches the extension', () {
      expect(Attachment.contentTypeOf('a.pdf'), 'application/pdf');
      expect(Attachment.contentTypeOf('a.png'), 'image/png');
      expect(Attachment.contentTypeOf('a.jpg'), 'image/jpeg');
      expect(Attachment.contentTypeOf('a.jpeg'), 'image/jpeg');
      expect(Attachment.contentTypeOf('a.heic'), 'image/heic');
      expect(Attachment.contentTypeOf('a.webp'), 'image/webp');
    });

    test('never claims an image is a PDF', () {
      // The bucket serves back whatever it was told, and a JPEG labelled
      // application/pdf renders as nothing at all in both viewers.
      for (final ext in Attachment.imageExtensions) {
        expect(Attachment.contentTypeOf('file.$ext'), isNot('application/pdf'));
      }
    });

    test('falls back rather than guessing', () {
      expect(Attachment.contentTypeOf('mystery'), 'application/octet-stream');
    });
  });

  group('isAllowed', () {
    test('covers exactly what the pickers offer', () {
      for (final ext in Attachment.allowedExtensions) {
        expect(Attachment.isAllowed('file.$ext'), isTrue, reason: ext);
      }
      expect(Attachment.isAllowed('file.exe'), isFalse);
    });
  });
}
