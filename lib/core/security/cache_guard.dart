import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
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
/// removed when the app is put away normally. Finding the marker still there
/// on the next launch means the previous run died on its feet, so the cache is
/// wiped before Firestore touches it.
///
/// The signal used to be a twelve-second timer: survive that long and the
/// launch counted as healthy. That only ever caught a crash during startup.
/// This crash is triggered by *reading a collection*, which happens whenever
/// somebody opens the screen that reads it — a minute in, or ten. Past the
/// twelve seconds the marker was already gone, nothing recorded that the app
/// had died, and the next launch left the bad row exactly where it was. The
/// app went on crashing on that screen forever, which is the report this
/// replaces.
///
/// Backgrounding is the honest signal instead: it is what a session ending
/// normally looks like, and a process killed in the foreground never reaches
/// it. The cost of a false positive is a re-download of cached data, not data
/// loss — everything lives on the server.
abstract final class FirestoreCacheGuard {
  static const String _markerName = 'firestore_boot.marker';

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

  /// Records that this session ended normally.
  ///
  /// Called when the app is backgrounded or detached. A process that dies in
  /// the foreground never gets here, which is exactly the case worth catching.
  static Future<void> markSessionEndedNormally() async {
    try {
      final marker = await _marker();
      if (marker.existsSync()) await marker.delete();
    } catch (_) {
      // Worst case the next launch clears a cache that was fine.
    }
  }

  /// Re-arms the marker when the app comes back to the foreground.
  ///
  /// Without this, a resumed session runs unguarded: the marker was removed
  /// on the way out, so a crash after coming back would leave nothing behind
  /// — and coming back is when the user opens the next screen.
  static Future<void> markSessionActive() async {
    try {
      final marker = await _marker();
      if (!marker.existsSync()) await marker.create(recursive: true);
    } catch (_) {
      // A guard that cannot arm simply does not fire.
    }
  }
}

/// Keeps [FirestoreCacheGuard]'s marker in step with the app's lifecycle.
///
/// Mounted once, above the router, for the life of the process.
class FirestoreCacheGuardScope extends StatefulWidget {
  const FirestoreCacheGuardScope({required this.child, super.key});

  final Widget child;

  @override
  State<FirestoreCacheGuardScope> createState() =>
      _FirestoreCacheGuardScopeState();
}

class _FirestoreCacheGuardScopeState extends State<FirestoreCacheGuardScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        FirestoreCacheGuard.markSessionEndedNormally();
      case AppLifecycleState.resumed:
        FirestoreCacheGuard.markSessionActive();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Transient — a notification shade pulled down, a call coming in.
        // Neither ends a session nor starts one.
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
