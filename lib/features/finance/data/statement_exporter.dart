import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Turns a laid-out statement widget into a shareable PDF.
///
/// The page is rasterised by Flutter and placed into the PDF as an image. That
/// is deliberate: drawing the text with PDF primitives would need an embedded
/// Arabic font and would still join letters incorrectly, whereas Flutter's own
/// text engine already shapes Arabic and handles right-to-left.
class StatementExporter {
  const StatementExporter();

  /// Renders [document] offscreen at [pixelRatio] and returns PNG bytes.
  ///
  /// Nothing is attached to the widget tree, so this works without the
  /// statement ever being visible on screen — and that is the catch. This
  /// render has **no inherited widgets at all**: no MaterialApp, no
  /// Directionality, and no `ProviderScope`. [document] must therefore carry
  /// everything it reads.
  ///
  /// Getting that wrong does not throw here. Flutter renders its error box
  /// instead, and the rasteriser faithfully captures it — which is how a
  /// statement came out as a red page reading "Bad state: No ProviderScope
  /// found", saved and shared as if it were the real thing.
  Future<Uint8List> renderToImage(
    Widget document, {
    required Size size,
    double pixelRatio = 2.0,
  }) async {
    final repaintBoundary = RenderRepaintBoundary();
    final view = WidgetsBinding.instance.platformDispatcher.views.first;

    final renderView = RenderView(
      view: view,
      child: RenderPositionedBox(child: repaintBoundary),
      configuration: ViewConfiguration(
        physicalConstraints: BoxConstraints.tight(size) * pixelRatio,
        logicalConstraints: BoxConstraints.tight(size),
        devicePixelRatio: pixelRatio,
      ),
    );

    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    renderView.prepareInitialFrame();

    final buildOwner = BuildOwner(focusManager: FocusManager());
    final element = RenderObjectToWidgetAdapter<RenderBox>(
      container: repaintBoundary,
      // No Directionality forced here: the caller wraps the document, because
      // an Arabic statement has to lay out right-to-left and this had been
      // pinning every statement to LTR.
      child: document,
    ).attachToRenderTree(buildOwner);

    buildOwner
      ..buildScope(element)
      ..finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();

    final image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw StateError('Could not rasterise the statement');
    }
    return byteData.buffer.asUint8List();
  }

  /// Wraps [pngBytes] in a single-page A4 PDF.
  Uint8List buildPdf(Uint8List pngBytes) {
    final pdf = PdfDocument();
    try {
      final page = pdf.pages.add();
      final bitmap = PdfBitmap(pngBytes);
      // Fill the page: the widget was laid out at A4 proportions already.
      page.graphics.drawImage(
        bitmap,
        Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height),
      );
      return Uint8List.fromList(pdf.saveSync());
    } finally {
      pdf.dispose();
    }
  }

  /// Writes the PDF to a temporary file and hands it to the platform's share
  /// sheet, which is what lets the user save it, mail it or print it.
  Future<void> share(Uint8List pdfBytes, {required String fileName}) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pdfBytes, flush: true);

    await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')]);
  }
}
