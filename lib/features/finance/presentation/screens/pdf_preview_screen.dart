import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/widgets/glass.dart';
import 'package:be_human_app/features/finance/data/statement_exporter.dart';

/// Shows a freshly generated PDF before it goes anywhere.
///
/// The statement used to jump straight to the share sheet, so nobody ever saw
/// what they were sending. That is how a page of red error text was shared
/// looking like a financial statement — a preview makes that impossible to
/// miss, and is what people expect anyway.
class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen({
    required this.bytes,
    required this.fileName,
    super.key,
  });

  final Uint8List bytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: GlassAppBar(
          title: AppLocalizations.of(context, 'statement_preview'),
          actions: [
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: AppLocalizations.of(context, 'share'),
              onPressed: () => _share(context),
            ),
          ],
        ),
        body: SfPdfViewer.memory(bytes),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _share(context),
          icon: const Icon(Icons.ios_share),
          label: Text(AppLocalizations.of(context, 'share')),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await const StatementExporter().share(bytes, fileName: fileName);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
