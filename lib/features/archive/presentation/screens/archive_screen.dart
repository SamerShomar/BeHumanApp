import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/widgets/app_fab.dart';
import 'package:be_human_app/core/widgets/glass.dart';
import 'package:be_human_app/core/widgets/state_views.dart';
import 'package:be_human_app/features/archive/domain/archive_models.dart';
import 'package:be_human_app/features/archive/presentation/providers/archive_providers.dart';
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
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: AppLocalizations.of(context, 'archive'),
        actions: const [NotificationBell()],
      ),
      body: userFolders.when(
        loading: () => const LoadingStateView(),
        error: (e, _) => ErrorStateView(error: e),
        data: (folders) => GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 120,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.15,
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
      floatingActionButton: AppFab(
        icon: Icons.create_new_folder_outlined,
        label: AppLocalizations.of(context, 'add_folder'),
        onPressed: () => _showCreateFolderDialog(context, ref),
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
    final theme = Theme.of(context);

    return GestureDetector(
      // Long-press deletes, but only a folder someone created — the two
      // derived folders reflect other collections and cannot be removed.
      onLongPress: folder.isSystem ? null : () => _confirmDelete(context, ref),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        // Through the router, not Navigator.push. The folder is a route of
        // its own outside the shell, so the navigation bar is correctly absent
        // instead of sitting on top of this screen's upload button — and
        // go_router still knows where the app is, so moving somewhere else
        // actually leaves.
        onTap: () => context.push('/archive/folder', extra: folder),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.brand.withOpacity(0.14),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Icon(
                folder.isSystem ? Icons.folder_special_outlined : Icons.folder_outlined,
                size: 28,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              folder.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
          ],
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
