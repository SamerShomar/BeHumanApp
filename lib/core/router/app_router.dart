import 'dart:ui';

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
import 'package:be_human_app/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:be_human_app/features/notifications/presentation/widgets/notification_toaster.dart';
import 'package:be_human_app/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/core/providers/auth_state_provider.dart';
import 'package:be_human_app/core/theme/app_colors.dart';
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
      // Tabs swap instantly. The default page transition slides a whole
      // screen in on every tap of the bottom bar, which on a bottom-nav app
      // reads as lag rather than polish — the destination is already "here".
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(location: state.matchedLocation, child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            name: 'home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/proposals',
            name: 'proposals',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProposalsListScreen()),
          ),
          GoRoute(
            path: '/financial',
            name: 'financial',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FinanceScreen()),
          ),
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminDashboardScreen()),
          ),
          GoRoute(
            path: '/archive',
            name: 'archive',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ArchiveScreen()),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsScreen()),
          ),
          GoRoute(
            path: '/notifications',
            name: 'notifications',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: NotificationsScreen()),
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
            // A short label: "Admin dashboard" does not fit a five-item bar.
            title: AppLocalizations.of(context, 'dashboard_short'),
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
    final role = ref.watch(currentUserStreamProvider).valueOrNull?.role;
    final items = role == null
        ? const <NavigationItem>[]
        : _itemsFor(context, role);

    final selectedIndex = items.indexWhere(
      (item) => location.startsWith(item.route),
    );

    return Scaffold(
      // Transparent so the app-wide gradient shows through; the backdrop is
      // painted once above the router, not per screen.
      backgroundColor: Colors.transparent,
      extendBody: true,
      // Wrapping the shell rather than each screen means an incoming
      // notification is announced wherever the user happens to be.
      body: NotificationToaster(child: child),
      bottomNavigationBar: items.isEmpty
          ? null
          : _GlassNavBar(items: items, selectedIndex: selectedIndex),
    );
  }
}

/// The frosted bar at the bottom of the shell.
///
/// `extendBody` on the Scaffold lets content scroll underneath it, which is
/// the whole point of making it translucent — a solid bar over a gradient
/// reads as a separate slab stuck to the screen.
class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.items, required this.selectedIndex});

  final List<NavigationItem> items;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.55),
            border: Border(top: BorderSide(color: AppColors.glassStroke(dark))),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var index = 0; index < items.length; index++)
                    _NavButton(
                      item: items[index],
                      isSelected: selectedIndex == index,
                      color: scheme.onSurface,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isSelected,
    required this.color,
  });

  final NavigationItem item;
  final bool isSelected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = isSelected ? AppColors.brand : color.withOpacity(0.55);

    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        child: InkWell(
          onTap: () => context.go(item.route),
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.brand.withOpacity(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, color: tint, size: 22),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tint,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
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
