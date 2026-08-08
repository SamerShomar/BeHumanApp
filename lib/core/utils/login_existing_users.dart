import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> loginExistingUsers() async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // User credentials to attempt login with
  final List<Map<String, dynamic>> userCredentials = [
    {
      'email': 'admin@behuman.org',
      'password': 'admin@2026',
    },
    {
      'email': 'samershomar@behuman.org',
      'password': '12345678',
    },
    {
      'email': 'mahmoudabuaisha@behuman.org',
      'password': '12345678',
    },
    {
      'email': 'lottegraat@behuman.org',
      'password': '12345678',
    },
    {
      'email': 'nelliewerner@behuman.org',
      'password': '12345678',
    },
    {
      'email': 'foekje@behuman.org',
      'password': '12345678',
    },
  ];

  for (var credential in userCredentials) {
    try {
      // Attempt to sign in
      UserCredential userCredential = await auth.signInWithEmailAndPassword(
        email: credential['email'],
        password: credential['password'],
      );
      
      print('Successfully logged in user: ${credential['email']}');
      
      // Verify user profile exists in Firestore
      final userDoc = await firestore.collection('users').doc(userCredential.user!.uid).get();
      if (!userDoc.exists) {
        print('Warning: User profile not found in Firestore for: ${credential['email']}');
      }
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('User not found: ${credential['email']} - Need to create user first');
      } else if (e.code == 'wrong-password') {
        print('Wrong password for: ${credential['email']}');
      } else {
        print('Login error for ${credential['email']}: ${e.message}');
      }
    } catch (e) {
      print('Unexpected error logging in user ${credential['email']}: $e');
    }
  }
}