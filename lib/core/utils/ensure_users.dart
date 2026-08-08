import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';

Future<void> ensureUsers() async {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // List of users to ensure exist
  final List<Map<String, dynamic>> usersToEnsure = [
    {
      'email': 'admin@behuman.org',
      'password': 'admin@2026',
      'name': 'Admin Be Human',
      'role': UserRole.admin,
      'team': UserTeam.netherlands,
    },
    {
      'email': 'samershomar@behuman.org',
      'password': '12345678',
      'name': 'Samer Shomar',
      'role': UserRole.member,
      'team': UserTeam.gaza,
    },
    {
      'email': 'mahmoudabuaisha@behuman.org',
      'password': '12345678',
      'name': 'Mahmoud Abu Aisha',
      'role': UserRole.member,
      'team': UserTeam.gaza,
    },
    {
      'email': 'lottegraat@behuman.org',
      'password': '12345678',
      'name': 'Lotte Graat',
      'role': UserRole.manager,
      'team': UserTeam.netherlands,
    },
    {
      'email': 'nelliewerner@behuman.org',
      'password': '12345678',
      'name': 'Nellie Werner',
      'role': UserRole.manager,
      'team': UserTeam.netherlands,
    },
    {
      'email': 'foekje@behuman.org',
      'password': '12345678',
      'name': 'Foekje',
      'role': UserRole.manager,
      'team': UserTeam.netherlands,
    },
  ];

  for (var userData in usersToEnsure) {
    try {
      // First try to sign in to check if user exists
      try {
        await auth.signInWithEmailAndPassword(
          email: userData['email'],
          password: userData['password'],
        );
        
        // If we get here, user exists and is logged in
        print('User logged in successfully: ${userData['email']}');
        
        // Now check if profile exists in Firestore
        final user = auth.currentUser;
        if (user != null) {
          final userDoc = await firestore.collection('users').doc(user.uid).get();
          if (!userDoc.exists) {
            // Create profile in Firestore
            final appUser = AppUser(
              uid: user.uid,
              email: userData['email'],
              name: userData['name'],
              role: userData['role'],
              team: userData['team'],
              createdAt: DateTime.now(),
            );
            await firestore.collection('users').doc(user.uid).set(appUser.toJson());
            print('Created user profile: ${userData['email']}');
          } else {
            print('User profile already exists: ${userData['email']}');
          }
        }
        
        // Sign out to prepare for next user
        await auth.signOut();
        
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'wrong-password') {
          // User doesn't exist, create new user
          try {
            final userCredential = await auth.createUserWithEmailAndPassword(
              email: userData['email'],
              password: userData['password'],
            );

            // Create profile in Firestore
            final appUser = AppUser(
              uid: userCredential.user!.uid,
              email: userData['email'],
              name: userData['name'],
              role: userData['role'],
              team: userData['team'],
              createdAt: DateTime.now(),
            );
            await firestore.collection('users').doc(userCredential.user!.uid).set(appUser.toJson());
            print('Created new user and profile: ${userData['email']}');
            
          } on FirebaseAuthException catch (e) {
            print('Error creating user ${userData['email']}: ${e.message}');
          }
        } else {
          print('Error with user ${userData['email']}: ${e.message}');
        }
      }
    } catch (e) {
      print('Unexpected error with user ${userData['email']}: $e');
    }
  }
}