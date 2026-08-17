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

/// Completes once Firebase has actually said whether anyone is signed in.
///
/// Distinct from [signedInUidProvider], which answers "right now" and reads as
/// signed-out while the check is still in flight. The splash screen needs the
/// settled answer: reading the live value after a fixed delay sent an
/// already-signed-in user to the login screen whenever Firebase was slower
/// than the animation, and the router then bounced them to the home screen a
/// moment later.
///
/// A separate provider rather than awaiting [authStateProvider] at the call
/// site, so it can be overridden in a test without constructing a Firebase
/// `User`.
final signedInResolvedProvider = FutureProvider<bool>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  return user != null;
});
