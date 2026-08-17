import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:be_human_app/core/router/page_transitions.dart';

/// Motion is easy to write and easy to have quietly do nothing — a transition
/// builder that is never wired up looks exactly like one that is, until you
/// watch the screen. These check the frames rather than the code.
void main() {
  Widget app(GoRouter router) => MaterialApp.router(routerConfig: router);

  GoRouter tabRouter() => GoRouter(
        initialLocation: '/a',
        routes: [
          GoRoute(
            path: '/a',
            pageBuilder: (context, state) =>
                AppTransitions.tab(state.pageKey, const Text('A')),
          ),
          GoRoute(
            path: '/b',
            pageBuilder: (context, state) =>
                AppTransitions.tab(state.pageKey, const Text('B')),
          ),
        ],
      );

  double opacityOf(WidgetTester tester, String text) {
    final transitions = tester.widgetList<FadeTransition>(
      find.ancestor(
        of: find.text(text),
        matching: find.byType(FadeTransition),
      ),
    );
    // Nested fades multiply, which is what the eye sees.
    return transitions.fold<double>(1, (value, t) => value * t.opacity.value);
  }

  group('switching tabs', () {
    testWidgets('fades the new screen in rather than cutting to it',
        (tester) async {
      final router = tabRouter();
      await tester.pumpWidget(app(router));
      await tester.pumpAndSettle();

      router.go('/b');
      await tester.pump();
      // Just after the halfway point of the fade's own interval.
      await tester.pump(const Duration(milliseconds: 200));

      final opacity = opacityOf(tester, 'B');
      expect(opacity, greaterThan(0.0));
      expect(
        opacity,
        lessThan(1.0),
        reason: 'the screen appeared at once — no transition ran',
      );

      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'B'), moreOrLessEquals(1.0, epsilon: 0.001));
    });

    testWidgets('does not slide the screen across', (tester) async {
      // The reason tabs had no transition at all before: sliding a whole
      // screen sideways for a bottom-bar tap reads as lag, because the
      // destination is not further away — it is somewhere else at the same
      // level.
      final router = tabRouter();
      await tester.pumpWidget(app(router));
      await tester.pumpAndSettle();

      router.go('/b');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 130));

      final slides = tester.widgetList<SlideTransition>(
        find.ancestor(
          of: find.text('B'),
          matching: find.byType(SlideTransition),
        ),
      );
      for (final slide in slides) {
        expect(slide.position.value.dx, moreOrLessEquals(0, epsilon: 0.001));
      }
    });

    testWidgets('settles within its stated duration', (tester) async {
      final router = tabRouter();
      await tester.pumpWidget(app(router));
      await tester.pumpAndSettle();

      router.go('/b');
      await tester.pump();
      await tester.pump(AppTransitions.tabDuration);

      // Fully arrived by the time it says it will be. The outgoing page is
      // still in the tree for one more frame while the route is torn down,
      // which is Navigator's business, not the transition's — so the check is
      // that it is gone once everything settles.
      expect(opacityOf(tester, 'B'), moreOrLessEquals(1.0, epsilon: 0.001));

      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
    });
  });

  group('opening a screen from another', () {
    testWidgets('slides in from the end edge', (tester) async {
      final router = GoRouter(
        initialLocation: '/a',
        routes: [
          GoRoute(
            path: '/a',
            pageBuilder: (context, state) =>
                AppTransitions.tab(state.pageKey, const Text('A')),
            routes: [
              GoRoute(
                path: 'detail',
                pageBuilder: (context, state) =>
                    AppTransitions.push(state.pageKey, const Text('DETAIL')),
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(app(router));
      await tester.pumpAndSettle();

      router.push('/a/detail');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final slides = tester.widgetList<SlideTransition>(
        find.ancestor(
          of: find.text('DETAIL'),
          matching: find.byType(SlideTransition),
        ),
      );
      expect(slides, isNotEmpty, reason: 'nothing is sliding — no push motion');
      // Still on its way in: somewhere between the end edge and home.
      expect(
        slides.any((s) => s.position.value.dx > 0 && s.position.value.dx < 1),
        isTrue,
      );

      await tester.pumpAndSettle();
      for (final slide in tester.widgetList<SlideTransition>(
        find.ancestor(
          of: find.text('DETAIL'),
          matching: find.byType(SlideTransition),
        ),
      )) {
        expect(slide.position.value.dx, moreOrLessEquals(0, epsilon: 0.001));
      }
    });
  });

  test('the durations stay in the range that reads as motion', () {
    // Under about 200ms a fade reads as a flicker; over about 350ms a bottom
    // bar stops feeling responsive.
    expect(AppTransitions.tabDuration.inMilliseconds, inInclusiveRange(200, 350));
    expect(AppTransitions.pushDuration.inMilliseconds, inInclusiveRange(220, 420));
  });
}
