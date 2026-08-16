import 'dart:io';

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

  /// The page is a fixed A4 canvas. Pumped into the runner's default 800x600
  /// surface it is squeezed to 600 and reports an overflow that says nothing
  /// about the real render, which happens at full size.
  void usePageSizedSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(
      StatementDocument.pageWidth, StatementDocument.pageHeight,
    );
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget bareDocument() => Directionality(
        textDirection: TextDirection.rtl,
        child: StatementDocument(
          range: range,
          transactions: transactions,
          issuedBy: 'Samer Shomar',
        ),
      );

  testWidgets('fails silently when the container is not handed over', (tester) async {
    usePageSizedSurface(tester);
    // The regression itself. Note that nothing is thrown to the caller — the
    // error becomes pixels, which is why a broken statement was shareable.
    await tester.pumpWidget(bareDocument());

    final error = tester.takeException();
    expect(error, isNotNull);
    expect('$error', contains('ProviderScope'));
  });

  testWidgets('renders when a container is passed in', (tester) async {
    usePageSizedSurface(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: bareDocument()),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(StatementDocument), findsOneWidget);
  });

  testWidgets('a throwaway container carries the language the app is in',
      (tester) async {
    // What the export builds, and why it can be a bare container: the only
    // thing the document reads through a provider is the locale.
    usePageSizedSurface(tester);
    final container = ProviderContainer(
      overrides: [
        localeProvider.overrideWith(
          (ref) => LocaleNotifier()..setLocale(const Locale('ar')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: bareDocument()),
    );

    expect(tester.takeException(), isNull);
    expect(container.read(localeProvider), const Locale('ar'));
    // Proof it is actually used: the header is in Arabic, not the default.
    expect(
      find.text(AppLocalizations.translate(const Locale('ar'), 'app_title')),
      findsOneWidget,
    );
  });

  test('the export never reaches for the running app container', () {
    // The crash this guards against: mounting an UncontrolledProviderScope
    // makes that element the container's vsync, and the exporter's BuildOwner
    // is built once and never scheduled again. Handing it the *live* container
    // left the app's provider scheduler aimed at a dead element — the next
    // refresh queued a task nothing would run, and the one after it died on
    // "Only one task can be scheduled at a time", minutes later and on a
    // screen with nothing to do with statements.
    //
    // Checked by reading the source, deliberately. The failure needs a
    // BuildOwner that is never scheduled again, and flutter_test's binding
    // keeps pumping its own — every attempt to stage it here passed whichever
    // container was used, which would have made a green test mean nothing.
    // What is actually enforceable is the rule: this call site must build its
    // own container.
    final source = File('lib/features/finance/presentation/screens/'
            'finance_screen.dart')
        .readAsStringSync();

    expect(
      source,
      contains('UncontrolledProviderScope'),
      reason: 'the document still needs a scope handed to it',
    );
    expect(
      source,
      isNot(contains('ProviderScope.containerOf')),
      reason: 'the export must not mount the app\'s own container offscreen',
    );
    expect(
      source,
      contains('container.dispose()'),
      reason: 'the throwaway container has to be disposed',
    );
  });

  testWidgets('lays out right-to-left for an Arabic statement', (tester) async {
    usePageSizedSurface(tester);
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
