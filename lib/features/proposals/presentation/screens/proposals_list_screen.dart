import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/proposals/presentation/widgets/pdf_viewer_widget.dart';

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
              subtitle: Text('${p['status'] ?? ''} • ${p['submittedByName'] ?? ''}', style: theme.textTheme.bodyMedium),
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    if (file.bytes == null) {
      // Try to read from local file path
      if (file.path != null) {
        try {
          final fileBytes = await File(file.path!).readAsBytes();
          final base64Pdf = base64Encode(fileBytes);
          final id = 'p${DateTime.now().millisecondsSinceEpoch}';
          final newProposal = {
            'id': id,
            'title': file.name,
            'fileName': file.name,
            'pdfBase64': base64Pdf,
            'status': 'معلق',
            'date': DateTime.now().toIso8601String(),
            'amount': 0.0,
            'submittedBy': user.uid,
            'submittedByName': user.name,
          };

          try {
            final adminService = ref.read(firestoreAdminServiceProvider);
            await adminService.addProposal(newProposal);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context, 'proposal_added'))));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('فشل إضافة المقترح: ${e.toString()}')),
            );
          }
          return;
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل قراءة الملف: ${e.toString()}')),
          );
          return;
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم تحميل الملف')));
      return;
    }

    final base64Pdf = base64Encode(file.bytes!);
    final id = 'p${DateTime.now().millisecondsSinceEpoch}';
    final newProposal = {
      'id': id,
      'title': file.name,
      'fileName': file.name,
      'pdfBase64': base64Pdf,
      'status': 'معلق',
      'date': DateTime.now().toIso8601String(),
      'amount': 0.0,
      'submittedBy': user.uid,
      'submittedByName': user.name,
    };

    try {
      final adminService = ref.read(firestoreAdminServiceProvider);
      await adminService.addProposal(newProposal);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context, 'proposal_added'))));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إضافة المقترح: ${e.toString()}')),
      );
    }
  }

  Future<void> _showProposalDetails(BuildContext context, WidgetRef ref, Map<String, dynamic> p, AppUser? user) async {
    final isReviewer = user != null && (user.team == UserTeam.netherlands || user.isAdmin);

    if (p['pdfBase64'] != null && p['pdfBase64'] is String) {
      final base64Pdf = p['pdfBase64'] as String;
      
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(p['title'] ?? AppLocalizations.of(context, 'proposal_details')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${AppLocalizations.of(context, 'status')}: ${p['status'] ?? ''}'),
                const SizedBox(height: 8),
                Text('${AppLocalizations.of(context, 'submitted_by')}: ${p['submittedByName'] ?? ''}'),
                const SizedBox(height: 8),
                Text('${AppLocalizations.of(context, 'file_name')}: ${p['fileName'] ?? AppLocalizations.of(context, 'no_file')}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _openPdfViewer(context, base64Pdf);
                  },
                  child: const Text('عرض الـ PDF'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppLocalizations.of(context, 'close'))),
              if (isReviewer) ...[
                TextButton(
                  onPressed: () async {
                    try {
                      final adminService = ref.read(firestoreAdminServiceProvider);
                      await adminService.updateProposalStatus(p['id'], 'مقبول');
                      Navigator.of(ctx).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('فشل الموافقة: ${e.toString()}')),
                      );
                    }
                  },
                  child: Text(AppLocalizations.of(context, 'approve'), style: const TextStyle(color: Colors.green)),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      final adminService = ref.read(firestoreAdminServiceProvider);
                      await adminService.updateProposalStatus(p['id'], 'مرفوض');
                      Navigator.of(ctx).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('فشل الرفض: ${e.toString()}')),
                      );
                    }
                  },
                  child: Text(AppLocalizations.of(context, 'reject'), style: const TextStyle(color: Colors.red)),
                ),
              ],
            ],
          );
        },
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: Text(p['title'] ?? AppLocalizations.of(context, 'proposal_details')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${AppLocalizations.of(context, 'status')}: ${p['status'] ?? ''}'),
                const SizedBox(height: 8),
                Text('${AppLocalizations.of(context, 'submitted_by')}: ${p['submittedByName'] ?? ''}'),
                const SizedBox(height: 8),
                Text('${AppLocalizations.of(context, 'file_name')}: ${p['fileName'] ?? AppLocalizations.of(context, 'no_file')}'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(AppLocalizations.of(context, 'close'))),
              if (isReviewer) ...[
                TextButton(
                  onPressed: () async {
                    try {
                      final adminService = ref.read(firestoreAdminServiceProvider);
                      await adminService.updateProposalStatus(p['id'], 'مقبول');
                      Navigator.of(ctx).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('فشل الموافقة: ${e.toString()}')),
                      );
                    }
                  },
                  child: Text(AppLocalizations.of(context, 'approve'), style: const TextStyle(color: Colors.green)),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      final adminService = ref.read(firestoreAdminServiceProvider);
                      await adminService.updateProposalStatus(p['id'], 'مرفوض');
                      Navigator.of(ctx).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('فشل الرفض: ${e.toString()}')),
                      );
                    }
                  },
                  child: Text(AppLocalizations.of(context, 'reject'), style: const TextStyle(color: Colors.red)),
                ),
              ],
            ],
          );
        },
      );
    }
  }

  void _openPdfViewer(BuildContext context, String base64Pdf) {
    try {
      // Navigate to PDF viewer screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => PdfViewerWidget(base64Pdf: base64Pdf),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل فك تشفير PDF: ${e.toString()}')),
      );
    }
  }
}
