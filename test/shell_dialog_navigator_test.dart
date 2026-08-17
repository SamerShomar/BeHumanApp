import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Guards the mistake that made "add proposal" hang on a black screen.
///
/// Screens inside a ShellRoute have their own Navigator, but `showDialog`
/// pushes onto the root one. Capturing `Navigator.of(context)` from such a
/// screen and popping it therefore did not close the dialog — it popped the
/// shell's only page, leaving go_router asserting "you have popped the last
/// page off of the stack, there are no pages left to show". Hence a black
/// screen the app never came back from.
void main() {
  Widget app() {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        ShellRoute(
          builder: (context, state, child) => Scaffold(body: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    // rootNavigator: true is the whole point — see above.
                    final navigator = Navigator.of(context, rootNavigator: true);
                    showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Text('BUSY'),
                    );
                    await Future<void>.delayed(const Duration(milliseconds: 10));
                    navigator.pop();
                  },
                  child: const Text('GO'),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('popping the root navigator dismisses the dialog and keeps the screen',
      (tester) async {
    await tester.pumpWidget(app());

    await tester.tap(find.text('GO'));
    await tester.pump();
    expect(find.text('BUSY'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('BUSY'), findsNothing, reason: 'dialog should be gone');
    expect(find.text('GO'), findsOneWidget, reason: 'screen should still be there');
    expect(tester.takeException(), isNull);
  });
}
