import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

/// Recovers from a corrupt Firestore offline cache.
///
/// Firestore keeps its offline data in SQLite. Android reads rows through a
/// `CursorWindow` capped at 2 MB, and if a single cached row grows past that,
/// every query against the collection throws `SQLiteBlobTooBigException`.
/// Firestore treats that as unrecoverable, calls `panic()`, and takes the
/// process down with it:
///
///   SQLiteBlobTooBigException: Row too big to fit into CursorWindow
///     at SQLiteDocumentOverlayCache.getOverlays
///     at LocalDocumentsView.getDocumentsMatchingCollectionQuery
///
/// It is a native crash, so no Dart `try` can catch it, and it repeats on
/// every launch because the bad row is on disk — the app is bricked for that
/// user until someone clears the app's storage by hand.
///
/// This makes it self-healing instead. A marker file is written at startup and
/// removed once the app has been running long enough to be considered healthy.
/// Finding the marker still there on launch means the previous run died before
/// that point, so the cache is wiped before Firestore touches it.
///
/// The cost of a false positive — a user force-closing the app within the
/// first few seconds — is a re-download of cached data, not data loss:
/// everything lives on the server.
abstract final class FirestoreCacheGuard {
  static const String _markerName = 'firestore_boot.marker';

  /// How long a launch must survive before it counts as healthy. Long enough
  /// to cover signing in and the first screen's queries, which is where this
  /// crash happens.
  static const Duration settleDelay = Duration(seconds: 12);

  static Timer? _settleTimer;

  static Future<File> _marker() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$_markerName');
  }

  /// Wipes the cache if the previous launch never completed.
  ///
  /// Must run **before any other Firestore call** — `clearPersistence` throws
  /// once a Firestore instance has started work.
  ///
  /// Returns true when a recovery actually happened, which the caller may want
  /// to log; it is never surfaced to the user, who would not know what to do
  /// with it.
  static Future<bool> recoverIfPreviousLaunchFailed() async {
    try {
      final marker = await _marker();
      final previousLaunchFailed = marker.existsSync();

      if (previousLaunchFailed) {
        await FirebaseFirestore.instance.clearPersistence();
        await marker.delete();
      }

      await marker.create(recursive: true);
      return previousLaunchFailed;
    } catch (_) {
      // A guard that cannot run must not itself stop the app from starting.
      return false;
    }
  }

  /// Starts the countdown after which this launch is considered healthy.
  ///
  /// Called once the first frame is on screen; the delay covers the queries
  /// that run just after it.
  static void markLaunchHealthyAfterDelay() {
    _settleTimer?.cancel();
    _settleTimer = Timer(settleDelay, () async {
      try {
        final marker = await _marker();
        if (marker.existsSync()) await marker.delete();
      } catch (_) {
        // Worst case the next launch clears a cache that was fine.
      }
    });
  }
}
