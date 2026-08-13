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
  /// Firestore's offline cache is an unencrypted SQLite file. With it enabled,
  /// every proposal and financial record the user has viewed stays readable on
  /// the device even without the account password.
  ///
  /// The trade-off is real: with this off the app needs a live connection for
  /// every read and will not work offline. That is deliberate for financial and
  /// beneficiary data. Flip this to `true` only if working offline matters more
  /// than a seized device staying unreadable.
  static const bool allowOfflineCache = false;

  /// How long the app may sit untouched before signing the user out.
  static const Duration inactivityTimeout = Duration(minutes: 10);

  /// Applies settings that must be in place before Firestore is first used.
  static Future<void> apply() async {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: allowOfflineCache,
    );
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
