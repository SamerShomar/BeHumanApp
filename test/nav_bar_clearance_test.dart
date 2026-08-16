import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/router/app_router.dart';
import 'package:be_human_app/core/widgets/app_fab.dart';
import 'package:be_human_app/features/auth/domain/entities/app_user.dart';
import 'package:be_human_app/features/auth/presentation/providers/auth_provider.dart';

/// The add button must clear the floating navigation bar.
///
/// It did not. AppFab padded a flat 72 points, which is roughly the bar's own
/// height and ignores the system inset underneath it — so on any phone with a
/// gesture bar the button sat nineteen points behind it and could not be
/// tapped. The number is now derived, and these hold it there across the
/// insets real devices actually report.
void main() {
  const user = AppUser(
    uid: 'u1',
    email: 'u1@behuman.org',
    name: 'Samer',
    role: UserRole.admin,
    team: UserTeam.gaza,
  );

  /// Pumps a shell screen carrying an AppFab and returns how far the button's
  /// bottom edge clears the bar's top edge. Negative means overlapping.
  Future<double> clearance(WidgetTester tester, double bottomInset) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = FakeViewPadding(bottom: bottomInset * 3);
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/archive',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              MainShell(location: state.matchedLocation, child: child),
          routes: [
            GoRoute(
              path: '/archive',
              builder: (_, __) => Scaffold(
                backgroundColor: Colors.transparent,
                body: const SizedBox(),
                floatingActionButton: AppFab(
                  icon: Icons.add,
                  label: 'add',
                  onPressed: () {},
                ),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserStreamProvider.overrideWith((ref) => Stream.value(user)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final fab = tester.getRect(find.byType(FloatingActionButton));
    // The bar is the last thing laid out against the bottom of the screen.
    final bar = tester.getRect(find.byType(MainShell).first);
    final screenHeight = bar.height;
    final barTop = screenHeight -
        (NavBarInset.barHeight + tester.view.padding.bottom / tester.view.devicePixelRatio);

    return barTop - fab.bottom;
  }

  for (final inset in <double>[0, 24, 34, 48]) {
    testWidgets('the add button clears the bar with a ${inset}pt inset',
        (tester) async {
      final gap = await clearance(tester, inset);
      expect(
        gap,
        greaterThanOrEqualTo(0),
        reason: 'the button is ${-gap}pt behind the navigation bar',
      );
    });
  }

  testWidgets('the bar is exactly as tall as AppFab assumes', (tester) async {
    // AppFab cannot measure the bar — it is built in a different subtree — so
    // it carries the height as a constant. This is what keeps that constant
    // honest when the bar's padding or label size changes.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(bottom: 0);
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/archive',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              MainShell(location: state.matchedLocation, child: child),
          routes: [
            GoRoute(
              path: '/archive',
              builder: (_, __) => const Scaffold(
                backgroundColor: Colors.transparent,
                body: SizedBox(),
              ),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserStreamProvider.overrideWith((ref) => Stream.value(user)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(MainShell),
        matching: find.byType(Scaffold),
      ).first,
    );
    expect(scaffold.bottomNavigationBar, isNotNull);

    final barRect = tester.getRect(find.byWidget(scaffold.bottomNavigationBar!));
    expect(
      barRect.height,
      closeTo(NavBarInset.barHeight, 2),
      reason: 'NavBarInset.barHeight is ${NavBarInset.barHeight} but the bar '
          'measures ${barRect.height}',
    );
  });
}
