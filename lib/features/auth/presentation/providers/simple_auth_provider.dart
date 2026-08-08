import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';

// Simple authentication provider that works without Firebase
class SimpleAuthProvider {
  SimpleAuthProvider();

  // Mock user data for testing
  final Map<String, AppUser> _mockUsers = {
    'admin@behuman.org': AppUser(
      uid: '1',
      email: 'admin@behuman.org',
      name: 'Admin Be Human',
      role: UserRole.admin,
      team: UserTeam.netherlands,
      createdAt: DateTime.now(),
    ),
    'samershomar@behuman.org': AppUser(
      uid: '2',
      email: 'samershomar@behuman.org',
      name: 'Samer Shomar',
      role: UserRole.member,
      team: UserTeam.gaza,
      createdAt: DateTime.now(),
    ),
    'mahmoudabuaisha@behuman.org': AppUser(
      uid: '3',
      email: 'mahmoudabuaisha@behuman.org',
      name: 'Mahmoud Abu Aisha',
      role: UserRole.member,
      team: UserTeam.gaza,
      createdAt: DateTime.now(),
    ),
    'lottegraat@behuman.org': AppUser(
      uid: '4',
      email: 'lottegraat@behuman.org',
      name: 'Lotte Graat',
      role: UserRole.manager,
      team: UserTeam.netherlands,
      createdAt: DateTime.now(),
    ),
    'nelliewerner@behuman.org': AppUser(
      uid: '5',
      email: 'nelliewerner@behuman.org',
      name: 'Nellie Werner',
      role: UserRole.manager,
      team: UserTeam.netherlands,
      createdAt: DateTime.now(),
    ),
    'foekje@behuman.org': AppUser(
      uid: '6',
      email: 'foekje@behuman.org',
      name: 'Foekje',
      role: UserRole.manager,
      team: UserTeam.netherlands,
      createdAt: DateTime.now(),
    ),
  };

  Future<AppUser?> signIn(String email, String password) async {
    // Simple authentication check
    if (_mockUsers.containsKey(email) && password.isNotEmpty) {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));
      return _mockUsers[email]!;
    }
    throw Exception('Invalid email or password');
  }

  Future<void> signOut() async {
    // Simulate sign out
    await Future.delayed(const Duration(milliseconds: 200));
  }
}

final simpleAuthProvider = Provider<SimpleAuthProvider>((ref) => SimpleAuthProvider());

// Stream provider for current user
final currentUserStreamProvider = StreamProvider<AppUser?>((ref) {
  // Return a stream that emits the current user
  return Stream<AppUser?>.fromIterable([null]); // Start with null
});