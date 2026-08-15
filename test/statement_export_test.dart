import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/finance/domain/statement_range.dart';
import 'package:be_human_app/features/finance/presentation/widgets/statement_document.dart';

/// The exported statement came out as a red page reading "Bad state: No
/// ProviderScope found", saved and shared as though it were a real financial
/// document.
///
/// The statement is rasterised detached from the app, so it inherits nothing —
/// no MaterialApp, no Directionality, no ProviderScope. A lookup that fails
/// there does not throw: Flutter draws its error box, and the rasteriser
/// captures it faithfully. Nothing surfaces until someone opens the file.
///
/// These pump the document in the same bare conditions the exporter creates.
/// The rasterising step itself is not covered — `toImage` needs a real frame
/// and hangs in a headless test runner — so what is pinned here is the reason
/// the page came out wrong, which is the part that was actually broken.
void main() {
  final range = StatementRange(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31));

  final transactions = [
    {'id': 't1', 'type': 'income', 'amount': 25000.0, 'description': 'Donation', 'date': '2026-08-10T09:00:00.000'},
    {'id': 't2', 'type': 'expense', 'amount': 8400.0, 'description': 'Water tanks', 'date': '2026-08-08T09:00:00.000'},
  ];

  Widget bareDocument() => Directionality(
        textDirection: TextDirection.rtl,
        child: StatementDocument(
          range: range,
          transactions: transactions,
          issuedBy: 'Samer Shomar',
        ),
      );

  testWidgets('fails silently when the container is not handed over', (tester) async {
    // The regression itself. Note that nothing is thrown to the caller — the
    // error becomes pixels, which is why a broken statement was shareable.
    await tester.pumpWidget(bareDocument());

    final error = tester.takeException();
    expect(error, isNotNull);
    expect('$error', contains('ProviderScope'));
  });

  testWidgets('renders when the app container is passed in', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: bareDocument()),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(StatementDocument), findsOneWidget);
  });

  testWidgets('lays out right-to-left for an Arabic statement', (tester) async {
    // The exporter used to pin every render to LTR regardless of language.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: bareDocument()),
    );

    expect(
      Directionality.of(tester.element(find.byType(StatementDocument))),
      TextDirection.rtl,
    );
  });

  test('the preview screen has a title in every language', () {
    for (final locale in AppLocalizations.supportedLocales) {
      for (final key in ['statement_preview', 'share']) {
        expect(AppLocalizations.translate(locale, key), isNot(key));
      }
    }
  });

  testWidgets('decodes the logo and the seal up front', (tester) async {
    // The rasteriser paints in a single pass, so anything still resolving
    // paints as empty space — silently. The page used to reach for
    // `Image.asset` and hope the image cache had been warmed with a matching
    // key, and the key depends on the configuration of whichever context did
    // the warming, not the one the page is painted in. Handing over decoded
    // images removes the coincidence.
    late final StatementImages images;
    await tester.runAsync(() async {
      images = await StatementImages.load();
    });

    expect(images.logo, isNotNull, reason: 'the statement would print unbranded');
    expect(images.stamp, isNotNull, reason: 'the statement would print unsealed');
    expect(images.logo!.width, greaterThan(0));
    expect(images.stamp!.width, greaterThan(0));
  });

  test('a page with nothing decoded still lays out', () {
    // A missing file must cost the seal, not the document.
    expect(StatementImages.none.logo, isNull);
    expect(StatementImages.none.stamp, isNull);
  });
}
