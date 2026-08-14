import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/archive/domain/archive_models.dart';
import 'package:be_human_app/features/archive/presentation/providers/archive_providers.dart';
import 'package:be_human_app/features/archive/presentation/widgets/archive_actions.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/proposals/presentation/widgets/pdf_viewer_widget.dart';

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
    final user = ref.read(currentUserStreamProvider).valueOrNull;
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    try {
      await ref.read(archiveServiceProvider).addDocument(
            folderId: folder.id,
            fileName: file.name,
            bytes: bytes,
            uploaderUid: user.uid,
            uploaderName: user.name,
          );
      messenger.showSnackBar(SnackBar(content: Text(addedMessage)));
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
    final canPreview = entry.isOpenable && looksLikePdf(entry.fileName);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.insert_drive_file),
        title: Text(entry.fileName),
        subtitle: entry.subtitle == null ? null : Text(entry.subtitle!),
        onTap: canPreview
            ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PdfViewerWidget(
                      storagePath: entry.storagePath!,
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
