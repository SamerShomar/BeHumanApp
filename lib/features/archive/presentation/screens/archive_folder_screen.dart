import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/core/domain/attachment.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/services/file_storage_service.dart';
import 'package:be_human_app/core/widgets/attachment_viewer.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/archive/domain/archive_models.dart';
import 'package:be_human_app/features/archive/presentation/providers/archive_providers.dart';
import 'package:be_human_app/features/archive/presentation/widgets/archive_actions.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';

/// One folder's contents.
///
/// System folders (proposals, invoices) list documents pulled from those
/// collections and cannot be added to or removed from here — the proposal or
/// financial screen owns that. A user folder's documents come from
/// `archive_documents` and can be uploaded or deleted by anyone, matching how
/// the folders themselves work.
class ArchiveFolderScreen extends ConsumerWidget {
  const ArchiveFolderScreen({super.key, required this.folder});

  final ArchiveFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = folder.isSystem
        ? _systemEntries(ref)
        : ref.watch(archiveDocumentsProvider(folder.id)).whenData(
              (docs) => [
                for (final d in docs)
                  ArchiveEntry(
                    fileName: d['fileName'] as String? ?? '',
                    storagePath: d['storagePath'] as String?,
                    subtitle: d['uploadedByName'] as String?,
                    documentId: d['id'] as String?,
                  ),
              ],
            );

    return Scaffold(
      appBar: AppBar(title: Text(folder.name)),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${AppLocalizations.of(context, 'error_generic')}: $e')),
        data: (items) => items.isEmpty
            ? Center(
                child: Text(
                  AppLocalizations.of(context, 'no_documents_in_folder'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, i) => _EntryTile(entry: items[i], folder: folder),
              ),
      ),
      floatingActionButton: folder.isSystem
          ? null
          : FloatingActionButton(
              onPressed: () => _addDocument(context, ref),
              child: const Icon(Icons.upload_file),
            ),
    );
  }

  AsyncValue<List<ArchiveEntry>> _systemEntries(WidgetRef ref) {
    if (folder.id == ArchiveFolder.proposalsId) {
      return ref.watch(proposalsProvider).whenData(
            (proposals) => [
              for (final p in proposals)
                if (p['fileName'] is String)
                  ArchiveEntry(
                    fileName: p['fileName'] as String,
                    storagePath: p['pdfPath'] as String?,
                    subtitle: p['submittedByName'] as String?,
                  ),
            ],
          );
    }
    return ref.watch(transactionsProvider).whenData(
          (transactions) => [
            for (final t in transactions)
              if (t['fileName'] is String)
                ArchiveEntry(
                  fileName: t['fileName'] as String,
                  storagePath: t['filePath'] as String?,
                ),
          ],
        );
  }

  Future<void> _addDocument(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final addedMessage = AppLocalizations.of(context, 'document_added');
    final wrongTypeMessage = AppLocalizations.of(context, 'archive_file_types');
    final unreadableMessage = AppLocalizations.of(context, 'file_not_loaded');
    final user = ref.read(currentUserStreamProvider).valueOrNull;
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: Attachment.allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    // The picker filter is a hint the platform may not honour — some file
    // managers let any type through — so the extension is checked here too.
    if (!Attachment.isAllowed(file.name)) {
      messenger.showSnackBar(SnackBar(content: Text(wrongTypeMessage)));
      return;
    }

    // `withData` is best-effort. Android hands back a path and no bytes for
    // anything large, and reading the field alone made an upload of a big
    // scan or a full-resolution photo do nothing at all, silently — which is
    // exactly what "it only ever creates folders" looked like from outside.
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) {
      messenger.showSnackBar(SnackBar(content: Text(unreadableMessage)));
      return;
    }

    try {
      await ref.read(archiveServiceProvider).addDocument(
            folderId: folder.id,
            fileName: file.name,
            bytes: bytes,
            uploaderUid: user.uid,
            uploaderName: user.name,
          );
      messenger.showSnackBar(SnackBar(content: Text(addedMessage)));
    } on FileStorageException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.localized(context))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.folder});

  final ArchiveEntry entry;
  final ArchiveFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final kind = Attachment.kindOf(
      entry.fileName.isEmpty ? (entry.storagePath ?? '') : entry.fileName,
    );
    final canPreview = entry.isOpenable && kind.isViewable;

    return Card(
      child: ListTile(
        // The icon says which of the two a row is before it is opened.
        leading: Icon(switch (kind) {
          AttachmentKind.pdf => Icons.picture_as_pdf_outlined,
          AttachmentKind.image => Icons.image_outlined,
          AttachmentKind.other => Icons.insert_drive_file_outlined,
        }),
        title: Text(entry.fileName),
        subtitle: entry.subtitle == null ? null : Text(entry.subtitle!),
        onTap: canPreview
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AttachmentViewer(
                      storagePath: entry.storagePath!,
                      fileName: entry.fileName,
                      title: entry.fileName,
                    ),
                  ),
                )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.isOpenable)
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: AppLocalizations.of(context, 'download'),
                onPressed: () => downloadArchiveFile(
                  context,
                  ref,
                  storagePath: entry.storagePath!,
                  fileName: entry.fileName,
                ),
              ),
            if (!folder.isSystem && entry.documentId != null)
              IconButton(
                icon: Icon(Icons.delete_outline, color: scheme.error),
                tooltip: AppLocalizations.of(context, 'delete'),
                onPressed: () => _confirmDelete(context, ref),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final deletedMessage = AppLocalizations.of(context, 'document_deleted');
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirm) => AlertDialog(
        content: Text(AppLocalizations.of(context, 'delete_document_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirm).pop(false),
            child: Text(AppLocalizations.of(context, 'cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(confirm).pop(true),
            child: Text(AppLocalizations.of(context, 'delete'), style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(archiveServiceProvider).deleteDocument(entry.documentId!, entry.storagePath);
      messenger.showSnackBar(SnackBar(content: Text(deletedMessage)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
