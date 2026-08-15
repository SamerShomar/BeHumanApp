import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:be_human_app/core/providers/auth_state_provider.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';

// These are deliberately not autoDispose. With it, leaving a tab tore down the
// Firestore listener and returning re-subscribed from scratch, so every switch
// between tabs showed a spinner and a flash of empty screen. Held open, the
// data is simply there — which is what makes moving around feel instant.
//
// The cost is a handful of always-open snapshot listeners. For collections
// this small that is cheaper than re-reading them on every navigation.

final proposalsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  if (ref.watch(signedInUidProvider) == null) return Stream.value(const []);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('proposals')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList());
});

final transactionsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  if (ref.watch(signedInUidProvider) == null) return Stream.value(const []);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('transactions')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList());
});

final financesProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? [];
  final totalIncome = transactions.fold<double>(
    0.0,
    (sum, tx) => sum + ((tx['type'] == 'income') ? (tx['amount'] as num?)?.toDouble() ?? 0.0 : 0.0),
  );
  final totalExpense = transactions.fold<double>(
    0.0,
    (sum, tx) => sum + ((tx['type'] != 'income') ? (tx['amount'] as num?)?.toDouble() ?? 0.0 : 0.0),
  );
  return {
    'totalIncome': totalIncome,
    'totalExpense': totalExpense,
    'balance': totalIncome - totalExpense,
  };
});

/// Every user profile, for the admin dashboard's member list.
final usersProvider = StreamProvider<List<AppUser>>((ref) {
  if (ref.watch(signedInUidProvider) == null) return Stream.value(const []);
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore.collection('users').snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) {
              try {
                return AppUser.fromJson(doc.data());
              } catch (_) {
                // A malformed profile should not blank the whole list.
                return null;
              }
            })
            .whereType<AppUser>()
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
      );
});

class FirestoreAdminService {
  FirestoreAdminService(this._firestore);

  final FirebaseFirestore _firestore;

  /// Changes a member's role. Firestore rules restrict this to admins, so a
  /// non-admin caller is rejected server-side regardless of the UI.
  Future<void> updateUserRole(String uid, UserRole role) async {
    // `role.name`, not `role.toString()`: the generated serializer stores the
    // bare enum name, and AppUser.fromJson fails to decode anything else.
    await _firestore
        .collection('users')
        .doc(uid)
        .set({'role': role.name}, SetOptions(merge: true));
  }

  Future<void> addProposal(Map<String, dynamic> proposal) async {
    await _firestore.collection('proposals').doc(proposal['id'] as String).set(proposal);
  }

  Future<void> updateProposalStatus(String id, String status) async {
    await _firestore.collection('proposals').doc(id).set({'status': status}, SetOptions(merge: true));
  }

  Future<void> deleteProposal(String id) async {
    await _firestore.collection('proposals').doc(id).delete();
  }

  Future<void> deleteTransaction(String id) async {
    await _firestore.collection('transactions').doc(id).delete();
  }

  Future<void> addTransaction(Map<String, dynamic> transaction) async {
    await _firestore.collection('transactions').doc(transaction['id'] as String).set(transaction);
  }
}

final firestoreAdminServiceProvider = Provider<FirestoreAdminService>((ref) => FirestoreAdminService(ref.watch(firebaseFirestoreProvider)));
