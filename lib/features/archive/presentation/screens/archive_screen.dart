import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/archive/domain/archive_models.dart';
import 'package:be_human_app/features/archive/presentation/providers/archive_providers.dart';
import 'package:be_human_app/features/archive/presentation/screens/archive_folder_screen.dart';
import 'package:be_human_app/features/notifications/presentation/widgets/notification_bell.dart';

/// Archive landing screen: a folder per topic.
///
/// Two folders always exist — proposals and invoices — mirroring what is
/// already stored elsewhere in the app; they cannot be created or removed
/// here. Anyone can add further folders and delete the ones they no longer
/// need, including each other's: the archive was scoped as shared space, not
/// per-user.
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userFolders = ref.watch(archiveFoldersProvider);

    final systemFolders = [
      ArchiveFolder(
        id: ArchiveFolder.proposalsId,
        name: AppLocalizations.of(context, 'proposals'),
        isSystem: true,
      ),
      ArchiveFolder(
        id: ArchiveFolder.invoicesId,
        name: AppLocalizations.of(context, 'archive_invoice'),
        isSystem: true,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context, 'archive')),
        actions: const [NotificationBell()],
      ),
      body: userFolders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${AppLocalizations.of(context, 'error_generic')}: $e')),
        data: (folders) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemCount: systemFolders.length + folders.length,
          itemBuilder: (context, i) {
            final folder = i < systemFolders.length
                ? systemFolders[i]
                : folders[i - systemFolders.length];
            return _FolderTile(folder: folder);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateFolderDialog(context, ref),
        child: const Icon(Icons.create_new_folder_outlined),
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context, 'add_folder')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: AppLocalizations.of(context, 'folder_name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final createdMessage = AppLocalizations.of(context, 'folder_created');
              final name = controller.text;

              Navigator.of(dialogContext).pop();
              if (name.trim().isEmpty) return;

              try {
                await ref.read(archiveServiceProvider).createFolder(name);
                messenger.showSnackBar(SnackBar(content: Text(createdMessage)));
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('$e')));
              }
            },
            child: Text(AppLocalizations.of(context, 'save')),
          ),
        ],
      ),
    );
  }
}

class _FolderTile extends ConsumerWidget {
  const _FolderTile({required this.folder});

  final ArchiveFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ArchiveFolderScreen(folder: folder)),
        ),
        onLongPress: folder.isSystem ? null : () => _confirmDelete(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.folder, size: 44, color: scheme.primary),
              const SizedBox(height: 8),
              Text(
                folder.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final deletedMessage = AppLocalizations.of(context, 'folder_deleted');
    final scheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirm) => AlertDialog(
        content: Text(AppLocalizations.of(context, 'delete_folder_confirm')),
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
      await ref.read(archiveServiceProvider).deleteFolder(folder.id);
      messenger.showSnackBar(SnackBar(content: Text(deletedMessage)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
