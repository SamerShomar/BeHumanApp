import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> debugLogin() async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  print('=== Starting Debug Login Process ===');
  
  // List of users to try
  final List<Map<String, dynamic>> usersToTry = [
    {'email': 'admin@behuman.org', 'password': 'admin@2026'},
    {'email': 'samershomar@behuman.org', 'password': '12345678'},
    {'email': 'mahmoudabuaisha@behuman.org', 'password': '12345678'},
    {'email': 'lottegraat@behuman.org', 'password': '12345678'},
    {'email': 'nelliewerner@behuman.org', 'password': '12345678'},
    {'email': 'foekje@behuman.org', 'password': '12345678'},
  ];

  for (var user in usersToTry) {
    try {
      print('Trying to login: ${user['email']}');
      
      // First try to sign in
      final userCredential = await auth.signInWithEmailAndPassword(
        email: user['email'],
        password: user['password'],
      );
      
      print('✅ Successfully logged in: ${user['email']}');
      
      // Check user profile
      final userDoc = await firestore.collection('users').doc(userCredential.user!.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        print('✅ User profile found: ${userData?['name']} (${userData?['role']})');
      } else {
        print('❌ User profile not found in Firestore');
      }
      
      // Sign out for next attempt
      await auth.signOut();
      print('Signed out ${user['email']}');
      
    } on FirebaseAuthException catch (e) {
      print('❌ Login failed for ${user['email']}: ${e.message}');
    } catch (e) {
      print('❌ Error for ${user['email']}: $e');
    }
  }
  
  print('=== Debug Login Process Complete ===');
}