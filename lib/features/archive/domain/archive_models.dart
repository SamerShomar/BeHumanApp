/// A folder in the archive.
///
/// Two kinds exist. System folders are derived from existing collections —
/// every proposal PDF, every invoice — and cannot be created or removed,
/// because they only reflect what is already stored elsewhere. User folders
/// live in Firestore and hold documents uploaded straight into the archive.
class ArchiveFolder {
  const ArchiveFolder({
    required this.id,
    required this.name,
    required this.isSystem,
  });

  final String id;
  final String name;
  final bool isSystem;

  /// Identifiers for the two derived folders, kept out of Firestore so they
  /// cannot collide with a folder someone creates.
  static const String proposalsId = '__proposals';
  static const String invoicesId = '__invoices';

  static ArchiveFolder fromJson(Map<String, dynamic> json) => ArchiveFolder(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        isSystem: false,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// One file listed in the archive, wherever it came from.
class ArchiveEntry {
  const ArchiveEntry({
    required this.fileName,
    required this.storagePath,
    this.subtitle,
    this.documentId,
  });

  final String fileName;

  /// Null for records saved before files moved to storage: they are listed but
  /// cannot be opened or downloaded.
  final String? storagePath;

  final String? subtitle;

  /// Set only for documents the archive owns, which are the ones that can be
  /// deleted from here. A proposal's PDF is managed by the proposal.
  final String? documentId;

  bool get isOpenable => storagePath != null;
}
