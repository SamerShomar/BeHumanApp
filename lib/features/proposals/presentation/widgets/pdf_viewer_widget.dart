import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerWidget extends StatelessWidget {
  final String base64Pdf;

  const PdfViewerWidget({
    super.key,
    required this.base64Pdf,
  });

  @override
  Widget build(BuildContext context) {
    final pdfBytes = base64Decode(base64Pdf);

    return Scaffold(
      appBar: AppBar(
        title: const Text('عرض PDF'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SfPdfViewer.memory(pdfBytes),
    );
  }
}
