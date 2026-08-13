import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: BeHumanApp(),
      ),
    );

    // Verify the app builds and mounts its router-backed MaterialApp.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
