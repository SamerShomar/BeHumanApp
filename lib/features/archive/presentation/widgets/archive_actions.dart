import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/services/file_storage_service.dart';

/// Downloads [storagePath] and hands it to the platform share sheet.
///
/// There is no universal "Downloads folder" API across Android and iOS
/// without extra permissions, so a save is done the way the exported
/// statement already is: fetch the bytes, write them to a temp file, and let
/// the share sheet's own "Save to Files" / "Save to device" handle placing it
/// wherever the user picks.
Future<void> downloadArchiveFile(
  BuildContext context,
  WidgetRef ref, {
  required String storagePath,
  required String fileName,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final downloadingMessage = AppLocalizations.of(context, 'downloading');

  messenger.showSnackBar(
    SnackBar(content: Text(downloadingMessage), duration: const Duration(seconds: 30)),
  );

  try {
    final bytes = await ref.read(fileStorageServiceProvider).downloadBytes(storagePath);
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    messenger.hideCurrentSnackBar();
    await Share.shareXFiles([XFile(file.path)]);
  } on FileStorageException catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(e.localized(context))));
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('${AppLocalizations.of(context, 'error_generic')}: $e')),
    );
  }
}

/// True when [fileName] looks like a PDF, the only type this app can preview
/// in place — anything else offered by an archive folder must be downloaded
/// to be opened, since there is no in-app viewer for arbitrary file types.
bool looksLikePdf(String fileName) => fileName.toLowerCase().endsWith('.pdf');
