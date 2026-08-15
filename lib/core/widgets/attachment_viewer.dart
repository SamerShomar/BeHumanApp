import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'package:be_human_app/core/domain/attachment.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/services/file_storage_service.dart';

/// Opens a stored attachment, whatever kind it is.
///
/// Receipts and archive documents used to go straight to the PDF viewer,
/// which is correct for a scan and blank for a photograph — the viewer is
/// handed an image and has nothing to do with it. The kind is read from the
/// file name and the right viewer is chosen here, so neither caller has to
/// know the difference.
class AttachmentViewer extends ConsumerStatefulWidget {
  const AttachmentViewer({
    super.key,
    required this.storagePath,
    required this.fileName,
    this.title,
  });

  /// Object path inside the storage bucket, as saved on the record.
  final String storagePath;

  /// Used only to tell a scan from a photo. Records written before the name
  /// was stored can pass the storage path itself — it carries the extension.
  final String fileName;

  final String? title;

  @override
  ConsumerState<AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends ConsumerState<AttachmentViewer> {
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
    final scheme = Theme.of(context).colorScheme;
    // The name is the honest source, but an older record may not have one; the
    // storage path ends in the same extension, so it answers just as well.
    final kind = Attachment.kindOf(
      widget.fileName.isEmpty ? widget.storagePath : widget.fileName,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? AppLocalizations.of(context, 'view_file')),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      body: FutureBuilder<String>(
        future: _signedUrl,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Failure(
              message: switch (snapshot.error) {
                final FileStorageException e => e.localized(context),
                final Object e => '$e',
                _ => AppLocalizations.of(context, 'error_generic'),
              },
            );
          }

          final url = snapshot.data!;
          return switch (kind) {
            AttachmentKind.pdf => SfPdfViewer.network(url),
            // Pinch to zoom, because a photographed transfer notice is
            // usually only readable once it is enlarged.
            AttachmentKind.image => Container(
                color: Colors.black,
                child: InteractiveViewer(
                  maxScale: 6,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, _, __) => _Failure(
                        message: AppLocalizations.of(context, 'file_open_failed'),
                      ),
                    ),
                  ),
                ),
              ),
            // Nothing else can be stored through the app, so this is only
            // reachable for a record written by hand.
            AttachmentKind.other => _Failure(
                message: AppLocalizations.of(context, 'file_type_not_viewable'),
              ),
          };
        },
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
