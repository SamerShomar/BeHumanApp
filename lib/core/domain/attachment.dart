/// What kind of file an attachment is, worked out from its name.
///
/// The app stores two things people actually attach: a transfer notice, and
/// whatever a folder in the archive is for. Both arrive either as a scan (PDF)
/// or as a photo taken on a phone, which is how most receipts reach anyone in
/// practice. Treating "attachment" as a synonym for "PDF" is what made the
/// picker reject the more common of the two.
enum AttachmentKind {
  pdf,
  image,
  other;

  bool get isViewable => this != AttachmentKind.other;
}

/// The file types an attachment may be, and how to recognise one.
class Attachment {
  const Attachment._();

  static const List<String> imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'heic',
    'heif',
    'webp',
  ];

  /// Everything the pickers offer. PDF first: it is what an official notice
  /// usually is, so it leads the list the file manager shows.
  static const List<String> allowedExtensions = ['pdf', ...imageExtensions];

  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  static AttachmentKind kindOf(String fileName) {
    final ext = extensionOf(fileName);
    if (ext == 'pdf') return AttachmentKind.pdf;
    if (imageExtensions.contains(ext)) return AttachmentKind.image;
    return AttachmentKind.other;
  }

  static bool isAllowed(String fileName) =>
      kindOf(fileName) != AttachmentKind.other;

  /// What to hand the storage bucket.
  ///
  /// Wrong here is not cosmetic: an image uploaded as `application/pdf` is
  /// served back with that header, and the browser and the in-app viewer both
  /// then refuse to render it.
  static String contentTypeOf(String fileName) {
    return switch (extensionOf(fileName)) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'jpg' || 'jpeg' => 'image/jpeg',
      _ => 'application/octet-stream',
    };
  }
}
