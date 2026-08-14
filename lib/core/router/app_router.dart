
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:be_human_app/features/auth/presentation/screens/login_screen.dart';
import 'package:be_human_app/features/home/presentation/screens/home_screen.dart';
import 'package:be_human_app/features/proposals/presentation/screens/proposals_list_screen.dart';
import 'package:be_human_app/features/finance/presentation/screens/finance_screen.dart';
import 'package:be_human_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:be_human_app/features/splash/presentation/screens/splash_screen.dart';
import 'package:be_human_app/features/no_internet/presentation/screens/no_internet_screen.dart';
import 'package:be_human_app/features/archive/presentation/screens/archive_screen.dart';
import 'package:be_human_app/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/providers/auth_state_provider.dart';
import 'package:be_human_app/core/providers/theme_provider.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';

/// Routes that are reachable without being signed in.
const _publicRoutes = {'/', '/splash', '/login', '/no-internet'};

/// The router is exposed as a provider so it can react to auth changes:
/// [refreshListenable] re-runs [GoRouter.redirect] every time the Firebase
/// auth stream emits, which is what makes sign-in and sign-out navigate on
/// their own.
final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = ValueNotifier<AsyncValue<User?>>(const AsyncLoading());
  ref.listen<AsyncValue<User?>>(
    authStateProvider,
    (_, next) => authListenable.value = next,
    fireImmediately: true,
  );
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final authState = authListenable.value;
      final location = state.matchedLocation;

      // While the auth stream has not produced its first value yet we cannot
      // tell signed-in from signed-out, so stay put instead of bouncing the
      // user to /login on every cold start.
      if (authState.isLoading) return null;

      final isLoggedIn = authState.valueOrNull != null;

      if (!isLoggedIn) {
        return _publicRoutes.contains(location) ? null : '/login';
      }

      // A signed-in user has no reason to sit on the login screen.
      if (location == '/login') return '/home';

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
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: '/archive',
            name: 'archive',
            builder: (context, state) => const ArchiveScreen(),
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
            Text(AppLocalizations.of(
              context, 'router_error', {'error': state.error.toString()},
            )),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: Text(AppLocalizations.of(context, 'back_to_login')),
            ),
          ],
        ),
      ),
    ),
  );
});

class MainShell extends ConsumerWidget {
  final String location;
  final Widget child;

  const MainShell({
    required this.location,
    required this.child,
    super.key,
  });

  /// The bottom bar is driven by the signed-in user's role. While the profile
  /// is still loading the list is empty and no bar is shown, which also keeps
  /// the shell from rendering a bar for a signed-out user.
  static List<NavigationItem> _itemsFor(BuildContext context, UserRole role) {
    final home = NavigationItem(
      title: AppLocalizations.of(context, 'home_title'),
      icon: Iconsax.home,
      route: '/home',
    );
    final proposals = NavigationItem(
      title: AppLocalizations.of(context, 'proposals'),
      icon: Iconsax.document,
      route: '/proposals',
    );
    final finance = NavigationItem(
      title: AppLocalizations.of(context, 'financial'),
      icon: Iconsax.wallet,
      route: '/financial',
    );
    final archive = NavigationItem(
      title: AppLocalizations.of(context, 'archive'),
      icon: Iconsax.archive,
      route: '/archive',
    );
    final settings = NavigationItem(
      title: AppLocalizations.of(context, 'settings'),
      icon: Iconsax.setting,
      route: '/settings',
    );

    switch (role) {
      case UserRole.member:
        // Finance is visible to members but read-only; the add button is
        // gated on hasFinancialAccess and the rules enforce it server-side.
        return [home, proposals, finance, archive, settings];
      case UserRole.manager:
        return [home, proposals, finance, archive, settings];
      case UserRole.admin:
        return [
          NavigationItem(
            title: AppLocalizations.of(context, 'admin_dashboard'),
            icon: Iconsax.home,
            route: '/dashboard',
          ),
          proposals,
          finance,
          archive,
          settings,
        ];
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);
    final role = ref.watch(currentUserStreamProvider).valueOrNull?.role;
    final items = role == null
        ? const <NavigationItem>[]
        : _itemsFor(context, role);

    final selectedIndex = items.indexWhere(
      (item) => location.startsWith(item.route),
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final scaffoldBackgroundColor = isDarkMode ? const Color(0xFF0A1628) : const Color(0xFFF0F4F8);
    final bottomNavColor = isDarkMode
        ? const Color(0xFF0A1628).withOpacity(0.9)
        : Colors.white.withOpacity(0.92);

    return Scaffold(
      body: child,
      backgroundColor: scaffoldBackgroundColor,
      bottomNavigationBar: items.isEmpty
          ? null
          : Container(
              decoration: BoxDecoration(
                color: bottomNavColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final isSelected = selectedIndex == index;

                      return GestureDetector(
                        onTap: () => context.go(item.route),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              const SizedBox(height: 4),
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

}
