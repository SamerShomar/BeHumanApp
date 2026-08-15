@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/finance/domain/statement_range.dart';
import 'package:be_human_app/features/finance/presentation/widgets/statement_document.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('Roboto');
    for (final path in [
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    ]) {
      final file = File(path);
      if (file.existsSync()) {
        loader.addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
      }
    }
    await loader.load();
  });

  final range = StatementRange(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31));
  final transactions = [
    {'id': 't1', 'type': 'income', 'amount': 25000.0, 'description': 'Donation — Rotterdam campaign', 'date': '2026-08-10T09:00:00.000'},
    {'id': 't2', 'type': 'expense', 'amount': 8400.0, 'description': 'Water tanks purchase', 'date': '2026-08-08T09:00:00.000'},
  ];

  for (final code in ['en', 'ar', 'nl']) {
    testWidgets('statement $code', (tester) async {
      tester.view.physicalSize = const Size(
        StatementDocument.pageWidth, StatementDocument.pageHeight,
      );
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(overrides: [
        localeProvider.overrideWith(
          (ref) => LocaleNotifier()..setLocale(Locale(code)),
        ),
      ]);
      addTearDown(container.dispose);

      late final StatementImages images;
      await tester.runAsync(() async {
        images = await StatementImages.load();
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: Directionality(
            textDirection: code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
            child: StatementDocument(
              range: range,
              transactions: transactions,
              issuedBy: 'Samer Shomar',
              images: images,
            ),
          ),
        ));
        // Real async so the asset images actually decode.
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump();

      await expectLater(
        find.byType(StatementDocument),
        matchesGoldenFile('goldens/statement_$code.png'),
      );
    }, skip: !Platform.isLinux);
  }
}
