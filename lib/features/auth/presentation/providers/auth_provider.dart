import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firebaseFirestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final currentUserStreamProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);

  return auth.authStateChanges().asyncMap((user) async {
    if (user == null) return null;

    final doc = await firestore.collection('users').doc(user.uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromJson(doc.data()!);
  });
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
    final credential =
        await auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = credential.user?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
          code: 'user-not-found', message: 'User not found after login.');
    }

    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      throw FirebaseException(
          plugin: 'be_human_app',
          message: 'User profile not found in Firestore.');
    }

    return AppUser.fromJson(doc.data()!);
  }

  Future<void> signOut() => auth.signOut();
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService(
    ref.watch(firebaseAuthProvider), ref.watch(firebaseFirestoreProvider)));
