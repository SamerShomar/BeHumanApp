
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:be_human_app/features/auth/presentation/screens/login_screen.dart';
import 'package:be_human_app/features/home/presentation/screens/home_screen.dart';
import 'package:be_human_app/features/proposals/presentation/screens/proposals_list_screen.dart';
import 'package:be_human_app/features/finance/presentation/screens/finance_screen.dart';
import 'package:be_human_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:be_human_app/features/splash/presentation/screens/splash_screen.dart';
import 'package:be_human_app/features/no_internet/presentation/screens/no_internet_screen.dart';
import 'package:be_human_app/core/providers/auth_state_provider.dart';
import 'package:be_human_app/core/providers/theme_provider.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authState = ProviderScope.containerOf(context).read(authStateProvider);
      final user = authState.when(
        data: (user) => user,
        loading: () => null,
        error: (error, stack) => null,
      );
      final isLoggedIn = user != null;
      
      // Non-authenticated users cannot access protected routes
      if (!isLoggedIn && state.matchedLocation != '/login') {
        return '/login';
      }
      
      // Authenticated users should not be on login screen
      if (isLoggedIn && state.matchedLocation == '/login') {
        return '/home';
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/no-internet',
        name: 'no-internet',
        builder: (context, state) => const NoInternetScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const HomeScreen(), // Temporary placeholder for admin dashboard
      ),
      GoRoute(
        path: '/archive',
        name: 'archive',
        builder: (context, state) => const HomeScreen(), // Temporary placeholder for archive
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(location: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/proposals',
            name: 'proposals',
            builder: (context, state) => const ProposalsListScreen(),
          ),
          GoRoute(
            path: '/financial',
            name: 'financial',
            builder: (context, state) => const FinanceScreen(),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('حدث خطأ: ${state.error.toString()}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('العودة لتسجيل الدخول'),
            ),
          ],
        ),
      ),
    ),
  );
}

class MainShell extends ConsumerStatefulWidget {
  final String location;
  final Widget child;

  const MainShell({
    required this.location,
    required this.child,
    super.key,
  });

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;
  late final List<NavigationItem> _navigationItems;
  UserRole _userRole = UserRole.member;

  @override
  void initState() {
    super.initState();
    _determineUserRole();
  }

  Future<void> _determineUserRole() async {
    final authState = ref.read(authStateProvider);
    final user = authState.when(
      data: (user) => user,
      loading: () => null,
      error: (error, stack) => null,
    );

    if (user == null) {
      setState(() {
        _navigationItems = [];
      });
      return;
    }

    // Try to get user role from Firestore first
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        _userRole = UserRole.values.firstWhere(
          (role) => role.toString() == userData?['role'],
          orElse: () => UserRole.member,
        );
      } else {
        // If document doesn't exist, create it with default role
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'email': user.email,
          'role': 'UserRole.member',
          'createdAt': FieldValue.serverTimestamp(),
        });
        _userRole = UserRole.member;
      }
    } catch (e) {
      // On any error, try to get from AppUser provider or fallback to member
      _userRole = UserRole.member;
    }

    setState(() {
      _buildNavigationItems();
      _setInitialIndex();
    });
  }

  void _buildNavigationItems() {
    switch (_userRole) {
      case UserRole.member:
        _navigationItems = [
          NavigationItem(title: 'Home', icon: Iconsax.home, route: '/home'),
          NavigationItem(title: 'Proposals', icon: Iconsax.document, route: '/proposals'),
          NavigationItem(title: 'Archive', icon: Iconsax.archive, route: '/archive'),
          NavigationItem(title: 'Settings', icon: Iconsax.setting, route: '/settings'),
        ];
        break;
      case UserRole.manager:
        _navigationItems = [
          NavigationItem(title: 'Home', icon: Iconsax.home, route: '/home'),
          NavigationItem(title: 'Proposals', icon: Iconsax.document, route: '/proposals'),
          NavigationItem(title: 'Finance', icon: Iconsax.wallet, route: '/financial'),
          NavigationItem(title: 'Archive', icon: Iconsax.archive, route: '/archive'),
          NavigationItem(title: 'Settings', icon: Iconsax.setting, route: '/settings'),
        ];
        break;
      case UserRole.admin:
        _navigationItems = [
          NavigationItem(title: 'Dashboard', icon: Iconsax.home, route: '/dashboard'),
          NavigationItem(title: 'Settings', icon: Iconsax.setting, route: '/settings'),
        ];
        break;
    }
  }

  void _setInitialIndex() {
    _selectedIndex = _navigationItems.indexWhere(
      (item) => widget.location.startsWith(item.route),
    );
    
    // Ensure we have a valid selected index, default to 0
    if (_selectedIndex == -1 && _navigationItems.isNotEmpty) {
      _selectedIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scaffoldBackgroundColor = isDarkMode ? const Color(0xFF0A1628) : const Color(0xFFF0F4F8);
    final bottomNavColor = isDarkMode 
        ? const Color(0xFF0A1628).withOpacity(0.9) 
        : Colors.white.withOpacity(0.92);

    return Scaffold(
      body: widget.child,
      backgroundColor: scaffoldBackgroundColor,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: bottomNavColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _navigationItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isSelected = _selectedIndex == index;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedIndex = index;
                    });
                    context.go(item.route);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF4A90D9).withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(
                              color: const Color(0xFF4A90D9),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          color: isSelected
                              ? const Color(0xFF4A90D9)
                              : colorScheme.onSurface.withOpacity(0.6),
                          size: 24,
                        ),
                        SizedBox(height: 4),
                        Text(
                          item.title,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFF4A90D9)
                                : colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class NavigationItem {
  final String title;
  final IconData icon;
  final String route;

  NavigationItem({
    required this.title,
    required this.icon,
    required this.route,
  });

  // New constructor for default items with built-in logic
  factory NavigationItem.home({
    required String route,
  }) {
    return NavigationItem(
      title: 'Home',
      icon: Iconsax.home,
      route: route,
    );
  }

  factory NavigationItem.proposals({
    required String route,
  }) {
    return NavigationItem(
      title: 'Proposals',
      icon: Iconsax.document,
      route: route,
    );
  }

  factory NavigationItem.finance({
    required String route,
  }) {
    return NavigationItem(
      title: 'Finance',
      icon: Iconsax.wallet,
      route: route,
    );
  }

  factory NavigationItem.archive({
    required String route,
  }) {
    return NavigationItem(
      title: 'Archive',
      icon: Iconsax.archive,
      route: route,
    );
  }

  factory NavigationItem.dashboard({
    required String route,
  }) {
    return NavigationItem(
      title: 'Dashboard',
      icon: Iconsax.home,
      route: route,
    );
  }

  factory NavigationItem.settings({
    required String route,
  }) {
    return NavigationItem(
      title: 'Settings',
      icon: Iconsax.setting,
      route: route,
    );
  }
}