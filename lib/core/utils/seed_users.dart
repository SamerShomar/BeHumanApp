import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';

Future<void> seedUsers() async {
  final List<Map<String, dynamic>> usersToSeed = [
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

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  for (var userData in usersToSeed) {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await auth.createUserWithEmailAndPassword(
        email: userData['email'],
        password: userData['password'],
      );

      final String uid = userCredential.user!.uid;

      // Create AppUser entity
      final appUser = AppUser(
        uid: uid,
        email: userData['email'],
        name: userData['name'],
        role: userData['role'],
        team: userData['team'],
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await firestore.collection('users').doc(uid).set(appUser.toJson());
      
      print('Successfully seeded user: ${userData['email']}');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        print('User already exists: ${userData['email']}');
      } else {
        print('Error seeding user ${userData['email']}: ${e.message}');
      }
    } catch (e) {
      print('Unexpected error seeding user ${userData['email']}: $e');
    }
  }
}
