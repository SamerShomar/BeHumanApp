import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
import 'package:be_human_app/core/utils/formatters.dart';
import 'package:be_human_app/core/widgets/app_fab.dart';
import 'package:be_human_app/core/widgets/glass.dart';
import 'package:be_human_app/core/widgets/state_views.dart';
import 'package:be_human_app/core/widgets/status_chip.dart';
import 'package:be_human_app/features/proposals/domain/proposal_permissions.dart';
import 'package:be_human_app/features/proposals/domain/proposal_status.dart';
import 'package:be_human_app/core/services/file_storage_service.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/proposals/presentation/widgets/pdf_viewer_widget.dart';
import 'package:be_human_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:be_human_app/features/notifications/presentation/widgets/notification_bell.dart';

/// Supabase rejects very large objects, and a huge proposal is more likely a
/// mistake than intent, so it is caught before the upload starts.
const _maxPdfBytes = 25 * 1024 * 1024;

class ProposalsListScreen extends ConsumerWidget {
  const ProposalsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserStreamProvider).value;
    final proposals = ref.watch(proposalsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: AppLocalizations.of(context, 'proposals'),
        actions: const [NotificationBell()],
      ),
      body: proposals.when(
        loading: () => const LoadingStateView(),
        error: (error, _) => ErrorStateView(error: error),
        data: (items) {
          if (items.isEmpty) {
            // All three of loading, failed and empty used to render the same
            // blank area, so a slow connection was indistinguishable from a
            // broken one.
            return EmptyStateView(
              icon: Icons.description_outlined,
              message: AppLocalizations.of(context, 'no_proposals'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 120,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _ProposalTile(
                proposal: items[index],
                onTap: () => _showProposalDetails(context, ref, items[index], user),
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: (user != null && user.team == UserTeam.gaza)
          ? AppFab(
              icon: Icons.add,
              label: AppLocalizations.of(context, 'add_proposal_new'),
              onPressed: () => _pickPdfAndAdd(context, ref, user),
            )
          : null,
    );
  }

  Future<void> _pickPdfAndAdd(BuildContext context, WidgetRef ref, AppUser user) async {
    final messenger = ScaffoldMessenger.of(context);
    final addedMessage = AppLocalizations.of(context, 'proposal_added');

    // This screen sits inside a ShellRoute, which has its own Navigator, while
    // showDialog pushes onto the root one. Popping the wrong navigator closed
    // the screen and left the dialog up — a black screen that never returned.
    final dialogNavigator = Navigator.of(context, rootNavigator: true);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      // Without this the picker returns only a path on some platforms.
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    final Uint8List? bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);

    if (bytes == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'file_not_loaded'))),
      );
      return;
    }

    if (bytes.lengthInBytes > _maxPdfBytes) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context, 'file_too_large'))),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context, 'uploading')),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final id = 'p${DateTime.now().millisecondsSinceEpoch}';
    try {
      // The PDF goes to Supabase and only its path is kept on the document —
      // a Firestore document cannot exceed 1 MiB.
      final storagePath = await ref
          .read(fileStorageServiceProvider)
          .uploadProposalPdf(proposalId: id, bytes: bytes);

      await ref.read(firestoreAdminServiceProvider).addProposal({
        'id': id,
        'title': file.name,
        'fileName': file.name,
        'pdfPath': storagePath,
        'status': ProposalStatus.pending,
        'date': DateTime.now().toIso8601String(),
        'amount': 0.0,
        'submittedBy': user.uid,
        'submittedByName': user.name,
      });

      // Only after the proposal is safely stored — a notification about a
      // proposal that failed to save would be worse than no notification.
      await ref.read(notificationServiceProvider).proposalSubmitted(
            actor: user,
            proposalId: id,
            title: file.name,
          );

      messenger.showSnackBar(SnackBar(content: Text(addedMessage)));
    } on FileStorageException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.localized(context))));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(
          context, 'proposal_add_failed', {'error': e.toString()},
        ))),
      );
    } finally {
      // In `finally` so an unexpected failure cannot strand the dialog.
      dialogNavigator.pop();
    }
  }

  Future<void> _showProposalDetails(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> p,
    AppUser? user,
  ) async {
    final storagePath = p['pdfPath'] is String ? p['pdfPath'] as String : null;
    final isReviewer = ProposalPermissions.canDecide(user);
    final canDelete = ProposalPermissions.canDelete(user, p);

    // Removing something already decided is a different act from withdrawing
    // a draft, so it asks a different question.
    final isDecided = !ProposalStatus.isPending(p['status']);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(p['title'] ?? AppLocalizations.of(context, 'proposal_details')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${AppLocalizations.of(context, 'status')}: ${ProposalStatus.label(context, p['status'])}'),
              const SizedBox(height: 8),
              Text('${AppLocalizations.of(context, 'submitted_by')}: ${p['submittedByName'] ?? ''}'),
              const SizedBox(height: 8),
              Text('${AppLocalizations.of(context, 'file_name')}: ${p['fileName'] ?? AppLocalizations.of(context, 'no_file')}'),
              if (storagePath != null) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    // Above the shell, so the navigation bar does not float
                    // across the bottom of the document being read.
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PdfViewerWidget(
                          storagePath: storagePath,
                          title: p['title'] as String?,
                        ),
                      ),
                    );
                  },
                  child: Text(AppLocalizations.of(context, 'view_pdf')),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context, 'close')),
            ),
            if (canDelete)
              _DeleteProposalButton(
                proposalId: p['id'] as String,
                storagePath: storagePath,
                isDecided: isDecided,
              ),
            if (isReviewer) ...[
              _StatusButton(
                proposalId: p['id'] as String,
                status: ProposalStatus.accepted,
                label: AppLocalizations.of(context, 'approve'),
                color: Colors.green,
                failureMessage: AppLocalizations.of(context, 'approve_failed'),
              ),
              _StatusButton(
                proposalId: p['id'] as String,
                status: ProposalStatus.rejected,
                label: AppLocalizations.of(context, 'reject'),
                color: Colors.red,
                failureMessage: AppLocalizations.of(context, 'reject_failed'),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// One proposal in the list.
///
/// It now carries what a reviewer actually needs to triage without opening
/// anything: the status as a coloured chip, who sent it, when, and for how
/// much. The old row showed only a title and a grey line of text.
class _ProposalTile extends StatelessWidget {
  const _ProposalTile({required this.proposal, required this.onTap});

  final Map<String, dynamic> proposal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = proposal['status'];

    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: StatusChip.colorFor(status).withOpacity(0.14),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Icon(
                  Icons.picture_as_pdf_outlined,
                  color: StatusChip.colorFor(status),
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proposal['title'] as String? ??
                          proposal['fileName'] as String? ??
                          AppLocalizations.of(context, 'proposal_placeholder'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${proposal['submittedByName'] ?? ''}'
                      '${proposal['date'] == null ? '' : '  •  ${Formatters.date(proposal['date'])}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              StatusChip(status: status, compact: true),
              const Spacer(),
              if ((proposal['amount'] as num?) != null &&
                  (proposal['amount'] as num) > 0)
                Text(
                  Formatters.amount(proposal['amount']),
                  style: theme.textTheme.titleSmall?.copyWith(color: AppColors.brand),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends ConsumerWidget {
  const _StatusButton({
    required this.proposalId,
    required this.status,
    required this.label,
    required this.color,
    required this.failureMessage,
  });

  final String proposalId;
  final String status;
  final String label;
  final Color color;
  final String failureMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        try {
          await ref
              .read(firestoreAdminServiceProvider)
              .updateProposalStatus(proposalId, status);
          navigator.pop();
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text('$failureMessage: ${e.toString()}')),
          );
        }
      },
      child: Text(label, style: TextStyle(color: color)),
    );
  }
}

/// Removes a proposal, with a confirmation step.
///
/// Reached two ways: a submitter withdrawing their own pending proposal, or an
/// admin removing one at any status.
class _DeleteProposalButton extends ConsumerWidget {
  const _DeleteProposalButton({
    required this.proposalId,
    this.storagePath,
    this.isDecided = false,
  });

  final String proposalId;
  final String? storagePath;

  /// Whether the proposal has already been accepted or rejected. Only changes
  /// what the confirmation says — removing a decided proposal takes something
  /// out of the record, and the question should say so.
  final bool isDecided;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return TextButton(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);
        final deletedMessage = AppLocalizations.of(context, 'proposal_deleted');

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (confirm) => AlertDialog(
            content: Text(AppLocalizations.of(
              context,
              isDecided
                  ? 'delete_decided_proposal_confirm'
                  : 'delete_proposal_confirm',
            )),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(confirm).pop(false),
                child: Text(AppLocalizations.of(context, 'cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.of(confirm).pop(true),
                child: Text(
                  AppLocalizations.of(context, 'delete'),
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
          ),
        );
        if (confirmed != true) return;

        try {
          await ref.read(firestoreAdminServiceProvider).deleteProposal(proposalId);

          // Remove the file too, but only after the document is gone: an
          // orphaned object is tidier than a proposal pointing at nothing.
          if (storagePath != null) {
            try {
              await ref.read(fileStorageServiceProvider).deleteFile(storagePath!);
            } on FileStorageException {
              // Nothing references it now; leaving it behind is acceptable.
            }
          }

          navigator.pop();
          messenger.showSnackBar(SnackBar(content: Text(deletedMessage)));
        } catch (e) {
          messenger.showSnackBar(SnackBar(content: Text('$e')));
        }
      },
      child: Text(
        AppLocalizations.of(context, 'delete'),
        style: TextStyle(color: scheme.error),
      ),
    );
  }
}
