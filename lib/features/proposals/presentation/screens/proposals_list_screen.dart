import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/proposals/domain/proposal_status.dart';
import 'package:be_human_app/core/services/file_storage_service.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/proposals/presentation/widgets/pdf_viewer_widget.dart';

/// Supabase rejects very large objects, and a huge proposal is more likely a
/// mistake than intent, so it is caught before the upload starts.
const _maxPdfBytes = 25 * 1024 * 1024;

class ProposalsListScreen extends ConsumerWidget {
  const ProposalsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserStreamProvider).value;
    final proposals = ref.watch(proposalsProvider);

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context, 'proposals'))),
      body: ListView.builder(
        padding: EdgeInsets.only(top: 12.h, bottom: 80.h, left: 12.w, right: 12.w),
        itemCount: proposals.value?.length ?? 0,
        itemBuilder: (context, index) {
          final p = proposals.value![index];
          return Card(
            margin: EdgeInsets.only(bottom: 12.h),
            color: scheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
              title: Text(p['title'] ?? p['fileName'] ?? AppLocalizations.of(context, 'proposal_placeholder'), style: theme.textTheme.bodyLarge),
              subtitle: Text('${ProposalStatus.label(context, p['status'])} • ${p['submittedByName'] ?? ''}', style: theme.textTheme.bodyMedium),
              onTap: () => _showProposalDetails(context, ref, p, user),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: (user != null && user.team == UserTeam.gaza)
          ? FloatingActionButton(
              onPressed: () => _pickPdfAndAdd(context, ref, user),
              backgroundColor: scheme.secondary,
              child: Icon(Icons.add, color: scheme.onSecondary),
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
    final isReviewer = user != null && (user.team == UserTeam.netherlands || user.isAdmin);
    final storagePath = p['pdfPath'] is String ? p['pdfPath'] as String : null;

    // Submitters may withdraw their own proposal while it is still pending.
    // Once reviewed it is part of the record, so it stays.
    final canDelete = user != null &&
        p['submittedBy'] == user.uid &&
        ProposalStatus.isPending(p['status']);

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
                    Navigator.of(context).push(
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

/// Withdraws a pending proposal, with a confirmation step.
class _DeleteProposalButton extends ConsumerWidget {
  const _DeleteProposalButton({required this.proposalId, this.storagePath});

  final String proposalId;
  final String? storagePath;

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
            content: Text(AppLocalizations.of(context, 'delete_proposal_confirm')),
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
