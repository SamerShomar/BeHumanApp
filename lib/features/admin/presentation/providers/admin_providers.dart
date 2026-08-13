import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';

final proposalsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('proposals')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
});

final transactionsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final firestore = ref.watch(firebaseFirestoreProvider);
  return firestore
      .collection('transactions')
      .orderBy('date', descending: true)
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
});

final financesProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? [];
  final totalIncome = transactions.fold<double>(
    0.0,
    (sum, tx) =>
        sum +
        ((tx['type'] == 'income')
            ? (tx['amount'] as num?)?.toDouble() ?? 0.0
            : 0.0),
  );
  final totalExpense = transactions.fold<double>(
    0.0,
    (sum, tx) =>
        sum +
        ((tx['type'] != 'income')
            ? (tx['amount'] as num?)?.toDouble() ?? 0.0
            : 0.0),
  );
  return {
    'totalIncome': totalIncome,
    'totalExpense': totalExpense,
    'balance': totalIncome - totalExpense,
  };
});

class FirestoreAdminService {
  FirestoreAdminService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> addProposal(Map<String, dynamic> proposal) async {
    await _firestore
        .collection('proposals')
        .doc(proposal['id'] as String)
        .set(proposal);
  }

  Future<void> updateProposalStatus(String id, String status) async {
    await _firestore
        .collection('proposals')
        .doc(id)
        .set({'status': status}, SetOptions(merge: true));
  }

  Future<void> addTransaction(Map<String, dynamic> transaction) async {
    await _firestore
        .collection('transactions')
        .doc(transaction['id'] as String)
        .set(transaction);
  }
}

final firestoreAdminServiceProvider = Provider<FirestoreAdminService>(
    (ref) => FirestoreAdminService(ref.watch(firebaseFirestoreProvider)));
