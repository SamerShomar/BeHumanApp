import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:be_human_app/core/security/security_settings.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// Whether a session exists right now, without waiting on the profile
/// document. Exposed as a provider so callers — and tests — do not have to
/// reach for FirebaseAuth.instance directly.
final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(firebaseAuthProvider).currentUser != null,
);

/// The signed-in user's profile, kept live.
///
/// Follows the Firestore document rather than reading it once per sign-in.
/// With a one-shot read, nothing written to the profile afterwards ever
/// reached the UI: a new avatar stayed invisible and a role changed from the
/// admin dashboard did not take effect until the user signed in again.
final currentUserStreamProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);

  final controller = StreamController<AppUser?>();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? profileSub;

  final authSub = auth.authStateChanges().listen((user) {
    // Drop the previous user's document listener before attaching the next.
    // asyncExpand would not do this: a Firestore snapshot stream never
    // completes, so a sign-out would queue behind it forever.
    profileSub?.cancel();
    profileSub = null;

    if (user == null) {
      controller.add(null);
      return;
    }

    profileSub = firestore.collection('users').doc(user.uid).snapshots().listen(
      (doc) {
        final data = doc.data();
        if (data == null) {
          controller.add(null);
          return;
        }
        try {
          controller.add(AppUser.fromJson(data));
        } catch (error, stackTrace) {
          // A malformed profile — a role saved as 'UserRole.admin' instead of
          // 'admin', say — should surface as an error rather than a silent
          // signed-out state.
          controller.addError(error, stackTrace);
        }
      },
      onError: controller.addError,
    );
  });

  ref.onDispose(() {
    profileSub?.cancel();
    authSub.cancel();
    controller.close();
  });

  return controller.stream;
});

// Remove manual StateProvider as we use the StreamProvider for real-time updates
// final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, AppUser?>((ref) {
//   return CurrentUserNotifier();
// });

// class CurrentUserNotifier extends StateNotifier<AppUser?> {
//   CurrentUserNotifier() : super(null);

//   void setUser(AppUser? user) {
//     state = user;
//   }

//   void clearUser() {
//     state = null;
//   }
// }

class AuthService {
  AuthService(this.auth, this.firestore);

  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  Future<AppUser> signIn(String email, String password) async {
    final credential = await auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = credential.user?.uid;
    if (uid == null) {
      throw FirebaseAuthException(code: 'user-not-found', message: 'User not found after login.');
    }

    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      throw FirebaseException(plugin: 'be_human_app', message: 'User profile not found in Firestore.');
    }

    return AppUser.fromJson(doc.data()!);
  }

  /// Sends a Firebase password-reset email.
  ///
  /// Firebase deliberately reports success even for an unknown address when
  /// email-enumeration protection is on, so the caller must not treat this as
  /// proof that the account exists.
  Future<void> sendPasswordReset(String email) async {
    await auth.sendPasswordResetEmail(email: email);
  }

  /// Firebase requires a recent login before a password change, so the current
  /// password is used to re-authenticate first.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user to change the password for.',
      );
    }

    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: currentPassword),
    );
    await user.updatePassword(newPassword);
  }

  /// Signs out and clears any locally cached documents, so a later holder
  /// of the device cannot read what the previous session viewed.
  Future<void> signOut() => SecuritySettings.signOutAndClearCache(auth);
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService(ref.watch(firebaseAuthProvider), ref.watch(firebaseFirestoreProvider)));

/// Edits a user makes to their own profile.
///
/// Kept apart from [AuthService], which deals with credentials. Firestore rules
/// let a user write their own document as long as `role` and `team` are
/// untouched, so these updates are merges of single fields.
class ProfileService {
  ProfileService(this._firestore);

  final FirebaseFirestore _firestore;

  /// Points the profile at a stored avatar, or clears it when [path] is null.
  Future<void> updatePhotoPath(String uid, String? path) async {
    await _firestore.collection('users').doc(uid).set(
      {'photoPath': path},
      SetOptions(merge: true),
    );
  }

  /// Remembers which language this user reads.
  ///
  /// The app knows the chosen locale on its own, but a push notification is
  /// composed on a server that has no way to ask — without this, an alert
  /// arriving on a closed phone would be in one fixed language for everyone.
  Future<void> updateLocale(String uid, String languageCode) async {
    await _firestore.collection('users').doc(uid).set(
      {'locale': languageCode},
      SetOptions(merge: true),
    );
  }
}

final profileServiceProvider = Provider<ProfileService>(
  (ref) => ProfileService(ref.watch(firebaseFirestoreProvider)),
);
