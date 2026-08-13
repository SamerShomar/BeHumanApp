import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/admin/presentation/providers/admin_providers.dart';
import 'package:be_human_app/features/proposals/presentation/widgets/pdf_viewer_widget.dart';

/// One archived attachment, from either collection.
class _ArchiveEntry {
  const _ArchiveEntry({
    required this.fileName,
    required this.type,
    required this.source,
    this.storagePath,
  });

  final String fileName;
  final String type;
  final String source;

  /// Null for older records saved before files moved to Supabase; those rows
  /// are listed but cannot be opened.
  final String? storagePath;

  bool get isOpenable => storagePath != null;
}

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proposals = ref.watch(proposalsProvider);
    final transactions = ref.watch(transactionsProvider);

    final items = <_ArchiveEntry>[
      for (final p in proposals.valueOrNull ?? const <Map<String, dynamic>>[])
        if (p['fileName'] is String)
          _ArchiveEntry(
            fileName: p['fileName'] as String,
            type: 'PDF',
            source: AppLocalizations.of(context, 'proposals'),
            storagePath: p['pdfPath'] as String?,
          ),
      for (final t in transactions.valueOrNull ?? const <Map<String, dynamic>>[])
        if (t['fileName'] is String)
          _ArchiveEntry(
            fileName: t['fileName'] as String,
            type: AppLocalizations.of(context, 'archive_invoice'),
            source: AppLocalizations.of(context, 'financial'),
            storagePath: t['filePath'] as String?,
          ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context, 'archive'))),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  AppLocalizations.of(context, 'no_file'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(item.fileName),
                    subtitle: Text('${item.type} • ${item.source}'),
                    trailing: item.isOpenable ? const Icon(Icons.open_in_new) : null,
                    enabled: item.isOpenable,
                    onTap: item.isOpenable
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => PdfViewerWidget(
                                  storagePath: item.storagePath!,
                                  title: item.fileName,
                                ),
                              ),
                            )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
