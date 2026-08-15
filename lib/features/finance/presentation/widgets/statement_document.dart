import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/finance/domain/money.dart';
import 'package:be_human_app/features/finance/domain/statement_range.dart';

/// The official financial statement, laid out as a widget.
///
/// Rendered by Flutter rather than drawn with PDF primitives: Flutter shapes
/// Arabic and lays out right-to-left correctly, whereas a PDF library needs an
/// embedded Arabic font and still gets joining wrong. The rendered page is
/// captured as an image and placed in the PDF, which also matches how a
/// stamped document is expected to look.
class StatementDocument extends StatelessWidget {
  const StatementDocument({
    super.key,
    required this.range,
    required this.transactions,
    required this.issuedBy,
    this.images = StatementImages.none,
  });

  /// A4 at 96dpi, so the captured image maps cleanly onto the PDF page.
  static const double pageWidth = 794;
  static const double pageHeight = 1123;

  final StatementRange range;
  final List<Map<String, dynamic>> transactions;
  final String issuedBy;

  /// Images decoded up front by the caller.
  ///
  /// The page is rasterised in one synchronous pass — build, layout, paint,
  /// capture — so anything resolved asynchronously has nothing to draw by the
  /// time the shutter closes, and paints as empty space without erroring.
  ///
  /// `Image.asset` is exactly that: asynchronous, and dependent on the image
  /// cache having been warmed with a matching key. Warming it worked, but only
  /// as long as the key matched — and the key is derived from the
  /// configuration of whichever context did the warming, which is not the
  /// context the page is painted in. Handing over already-decoded images
  /// removes the coincidence entirely.
  final StatementImages images;

  static final _date = DateFormat('yyyy-MM-dd');

  @override
  Widget build(BuildContext context) {
    final totals = MoneyTotals.of(transactions);

    // Fixed light styling: a printed document does not follow the app's theme.
    return Container(
      width: pageWidth,
      height: pageHeight,
      color: Colors.white,
      padding: const EdgeInsets.all(48),
      child: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF12233A), fontSize: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context),
            const SizedBox(height: 24),
            Divider(color: const Color(0xFF12233A).withOpacity(0.2), thickness: 1),
            const SizedBox(height: 16),
            _rangeLine(context),
            const SizedBox(height: 20),
            Expanded(child: _table(context)),
            const SizedBox(height: 16),
            _totals(context, totals),
            const SizedBox(height: 24),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    // Centred, stacked: the mark leads, then the organisation, then what the
    // document is.
    //
    // The width matters. The page's outer column aligns to the start, so this
    // block shrank to the width of its widest line and centred the logo inside
    // *that* — leaving it visibly left of the page's centre. Taking the full
    // width is what makes "centred" mean centred on the page.
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Picture(image: images.logo, size: 84),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context, 'app_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context, 'invoices_title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeLine(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            '${AppLocalizations.of(context, 'from_date')}: ${_date.format(range.from)}'
            '    ${AppLocalizations.of(context, 'to_date')}: ${_date.format(range.to)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            '${AppLocalizations.of(context, 'issued_on')}: ${_date.format(DateTime.now())}',
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _table(BuildContext context) {
    final border = BorderSide(color: const Color(0xFF12233A).withOpacity(0.15));

    if (transactions.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context, 'no_transactions_in_range'),
          style: TextStyle(color: const Color(0xFF12233A).withOpacity(0.6)),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: Table(
        border: TableBorder(horizontalInside: border, top: border, bottom: border),
        // Retuned for the fifth column. The description gives up the width the
        // euro column needs — a description can wrap onto a second line and
        // still be read, whereas a wrapped figure cannot.
        columnWidths: const {
          0: FlexColumnWidth(2.1),
          1: FlexColumnWidth(4.2),
          2: FlexColumnWidth(1.7),
          3: FlexColumnWidth(2.3),
          4: FlexColumnWidth(2.3),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: const Color(0xFF12233A).withOpacity(0.06)),
            children: [
              _cell(AppLocalizations.of(context, 'date_label'), style: _headerStyle),
              _cell(AppLocalizations.of(context, 'description_label'),
                  style: _headerStyle),
              _cell(AppLocalizations.of(context, 'type_label'), style: _headerStyle),
              _cell(AppLocalizations.of(context, 'amount_ils'),
                  style: _headerStyle, numeric: true),
              _cell(AppLocalizations.of(context, 'amount_eur'),
                  style: _headerStyle, numeric: true),
            ],
          ),
          for (final t in transactions)
            _movementRow(context, t),
        ],
      ),
    );
  }

  /// One movement, in both currencies.
  ///
  /// Shekels are what the money on the ground actually was; euro is what the
  /// donors gave. A statement that carries only one of the two has to be read
  /// with a calculator beside it, so both are printed and the conversion is
  /// the recorded rate's, not the reader's.
  ///
  /// A cell reads "—" when the rate needed was never recorded. That is
  /// deliberate: a printed financial record must not carry a figure nobody
  /// chose a rate for.
  TableRow _movementRow(BuildContext context, Map<String, dynamic> t) {
    final money = Money.fromTransaction(t);

    return TableRow(
      children: [
        _cell(_formatDate(t['date'])),
        _cell(t['description'] as String? ?? t['fileName'] as String? ?? ''),
        _cell(AppLocalizations.of(
          context,
          t['type'] == 'income' ? 'income_label' : 'expense_label',
        )),
        _cell(money.formattedIls, numeric: true),
        _cell(money.formattedEur, numeric: true),
      ],
    );
  }

  static const _headerStyle =
      TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5);

  /// One table cell.
  ///
  /// A figure is set left-to-right and aligned to the end of its column, no
  /// matter the document's language. Amounts are written the same way in
  /// Arabic as in English — "1,250.00 ₪", digits first — and letting an RTL
  /// paragraph reorder them moves the symbol to the wrong side and breaks the
  /// column of decimal points that makes a table of figures readable at all.
  Widget _cell(String text, {TextStyle? style, bool numeric = false}) {
    final content = Text(
      text,
      textAlign: numeric ? TextAlign.end : TextAlign.start,
      style: (style ?? const TextStyle()).copyWith(fontSize: style?.fontSize ?? 11.5),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: numeric
          // `ui.` qualified: intl exports a TextDirection of its own, and the
          // bare name resolves to that one here.
          ? Directionality(textDirection: ui.TextDirection.ltr, child: content)
          : content,
    );
  }

  /// The three summary figures, in both currencies.
  ///
  /// Laid out as a small table with the same two amount columns as the ledger
  /// above it, so a total sits directly under the column it totals rather than
  /// beside a label in a different shape.
  Widget _totals(BuildContext context, MoneyTotals totals) {
    final divider = BorderSide(color: const Color(0xFF12233A).withOpacity(0.25));

    TableRow line(String key, double ils, double eur, {bool bold = false}) {
      final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      );
      return TableRow(
        children: [
          _cell(AppLocalizations.of(context, key), style: style),
          _cell(Money.format(ils, StatementCurrency.ils),
              style: style, numeric: true),
          _cell(Money.format(eur, StatementCurrency.eur),
              style: style, numeric: true),
        ],
      );
    }

    // Aligned through the full page width, not just its own. A column that
    // shrinks to its content and is then told to align "end" ends up wherever
    // the parent puts the shrunken box — which is how this block, and the
    // header before it, drifted to the wrong side of the page.
    //
    // `AlignmentDirectional` rather than a fixed side, so an Arabic statement
    // puts its totals on the left where they belong.
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: SizedBox(
        width: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2.4),
                2: FlexColumnWidth(2.4),
              },
              children: [
                line('incoming', totals.incomeIls, totals.incomeEur),
                line('outgoing', totals.expenseIls, totals.expenseEur),
              ],
            ),
            Divider(color: divider.color, thickness: divider.width, height: 10),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3),
                1: FlexColumnWidth(2.4),
                2: FlexColumnWidth(2.4),
              },
              children: [
                line('balance_current', totals.balanceIls, totals.balanceEur,
                    bold: true),
              ],
            ),
            // Said out loud rather than hidden: a total that leaves rows out
            // must declare how many, or it is simply wrong. Counted per
            // column, because a row can be complete in shekels and missing
            // from euro — that is precisely what an unrecorded rate does.
            if (!totals.isIlsComplete || !totals.isEurComplete) ...[
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context, 'totals_missing_rate', {
                  'count': '${totals.missingIls > totals.missingEur ? totals.missingIls : totals.missingEur}',
                }),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 10.5,
                  color: const Color(0xFF12233A).withOpacity(0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${AppLocalizations.of(context, 'issued_by')}: $issuedBy'),
              const SizedBox(height: 6),
              Text(
                AppLocalizations.of(context, 'statement_note'),
                style: TextStyle(
                  fontSize: 11,
                  color: const Color(0xFF12233A).withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        // Enlarged: at 110 the seal read as an icon rather than a stamp.
        _Picture(image: images.stamp, size: 150),
      ],
    );
  }

  static String _formatDate(Object? raw) {
    final parsed = StatementRange.parseDate(raw);
    return parsed == null ? '' : _date.format(parsed);
  }

}

/// Draws an already-decoded image, or reserves its space when there is none.
///
/// A statement without the seal is better than one that invents it, and better
/// still than one whose layout shifts depending on whether a file loaded.
class _Picture extends StatelessWidget {
  const _Picture({required this.image, required this.size});

  final ui.Image? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (image == null) return SizedBox(width: size, height: size);
    return RawImage(
      image: image,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// The logo and seal, decoded ahead of rasterising the page.
class StatementImages {
  const StatementImages({this.logo, this.stamp});

  /// Nothing decoded — the page still lays out, just without its marks.
  static const StatementImages none = StatementImages();

  final ui.Image? logo;
  final ui.Image? stamp;

  static const String logoAsset = 'assets/images/logo.png';
  static const String stampAsset = 'assets/images/stamp.png';

  /// Decodes both, tolerating either being missing.
  ///
  /// Each decode is capped: one that never finishes must not leave the export
  /// button spinning. A statement missing its seal beats one that never
  /// arrives.
  static Future<StatementImages> load() async {
    Future<ui.Image?> decode(String asset) async {
      try {
        final data = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        return frame.image;
      } catch (_) {
        return null;
      }
    }

    try {
      final results = await Future.wait([decode(logoAsset), decode(stampAsset)])
          .timeout(const Duration(seconds: 8));
      return StatementImages(logo: results[0], stamp: results[1]);
    } catch (_) {
      return none;
    }
  }
}
