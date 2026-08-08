import 'package:flutter_test/flutter_test.dart';
import 'package:be_human_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: BeHumanApp(),
      ),
    );

    // Verify that the welcome text is present.
    expect(find.text('Welcome to Be Human Foundation'), findsOneWidget);
  });
}
