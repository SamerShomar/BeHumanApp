import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Firebase session, watched live.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Who is signed in, or null.
///
/// Every Firestore query in the app watches this. That is not decoration: the
/// data providers are no longer `autoDispose`, so without it a listener opened
/// during one person's session outlives their sign-out. Firestore then fails
/// it with permission-denied, the provider latches into an error state, and
/// nothing ever rebuilds it — so the next person to sign in meets "the caller
/// does not have permission" on every screen.
///
/// Watching the uid makes each query belong to a session: it is torn down when
/// that session ends and built again for the next one.
final signedInUidProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});
