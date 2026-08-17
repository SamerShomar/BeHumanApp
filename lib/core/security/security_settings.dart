import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Device-level protections for the data this app handles.
///
/// Transport and server-side storage are already encrypted: every Firebase and
/// Supabase call is TLS, and both encrypt at rest. The exposure that remains is
/// the *device* — a lost, stolen or seized phone. These settings address that.
class SecuritySettings {
  const SecuritySettings._();

  /// Whether Firestore may keep a local copy of documents on disk.
  ///
  /// Enabled deliberately: the app has to work through the connection outages
  /// its users live with, and Firestore's cache is what makes reads succeed and
  /// writes queue until the network returns.
  ///
  /// The cost is that the cache is an unencrypted SQLite file, so every
  /// proposal and transaction the user has viewed stays readable on the device
  /// without the account password. Sign-out clears it, `FLAG_SECURE` still
  /// blocks screenshots, and the device's own lock screen carries the rest.
  /// Set to `false` to keep nothing on disk, at the cost of offline use.
  static const bool allowOfflineCache = true;

  /// How long the app may sit untouched before signing the user out.
  static const Duration inactivityTimeout = Duration(minutes: 10);

  /// Whether a session must be re-entered every time the app is opened.
  ///
  /// Deliberately `false`: signing in on every launch was judged too heavy for
  /// daily use. Firebase Auth therefore keeps the signed-in user on disk and a
  /// restarted app resumes straight into the dashboard.
  ///
  /// The consequence is that whoever holds an unlocked device holds the
  /// organisation's records, so [inactivityTimeout] is now the main guard while
  /// the app is open, and the device's own lock screen carries the rest. Set
  /// this back to `true` to require a password on every launch.
  static const bool requireLoginOnLaunch = false;

  /// Ceiling on the offline cache.
  ///
  /// It used to be `CACHE_SIZE_UNLIMITED`, which switches Firestore's
  /// garbage collector off entirely — the cache only ever grew. A bound puts
  /// the collector back to work, evicting documents that are already on the
  /// server. Pending offline *writes* are never evicted by it, so an outage
  /// still holds everything it needs.
  ///
  /// 80 MB is far more than this app's records occupy and small enough that
  /// the cache cannot quietly become a liability.
  static const int cacheSizeBytes = 80 * 1024 * 1024;

  /// Applies settings that must be in place before Firestore or the router
  /// first read their state.
  static Future<void> apply() async {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: allowOfflineCache,
      cacheSizeBytes: allowOfflineCache ? cacheSizeBytes : null,
    );

    if (requireLoginOnLaunch) {
      await FirebaseAuth.instance.signOut();
    }
  }

  /// Signs out and drops any locally cached documents.
  ///
  /// `clearPersistence` only succeeds while no Firestore work is in flight, so
  /// it runs after sign-out and its failure must not block the sign-out itself.
  static Future<void> signOutAndClearCache(FirebaseAuth auth) async {
    await auth.signOut();
    try {
      await FirebaseFirestore.instance.clearPersistence();
    } on FirebaseException {
      // Nothing cached, or the client was still active — sign-out already
      // happened, which is the part that matters.
    }
  }
}
