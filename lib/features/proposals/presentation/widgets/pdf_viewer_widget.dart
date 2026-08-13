import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:be_human_app/core/services/file_storage_service.dart';

/// Shows a proposal PDF stored in Supabase.
///
/// The bucket is private, so the signed URL is minted here, when the file is
/// actually opened, rather than being stored alongside the proposal.
class PdfViewerWidget extends ConsumerStatefulWidget {
  const PdfViewerWidget({
    super.key,
    required this.storagePath,
    this.title,
  });

  /// Object path inside the proposals bucket, as saved on the Firestore doc.
  final String storagePath;
  final String? title;

  @override
  ConsumerState<PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends ConsumerState<PdfViewerWidget> {
  late Future<String> _signedUrl;

  @override
  void initState() {
    super.initState();
    _signedUrl = ref
        .read(fileStorageServiceProvider)
        .createSignedUrl(widget.storagePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'عرض PDF'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: FutureBuilder<String>(
        future: _signedUrl,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            );
          }

          return SfPdfViewer.network(snapshot.data!);
        },
      ),
    );
  }
}
