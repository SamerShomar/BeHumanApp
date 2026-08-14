import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
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
  });

  /// A4 at 96dpi, so the captured image maps cleanly onto the PDF page.
  static const double pageWidth = 794;
  static const double pageHeight = 1123;

  final StatementRange range;
  final List<Map<String, dynamic>> transactions;
  final String issuedBy;

  static final _date = DateFormat('yyyy-MM-dd');
  static final _money = NumberFormat('#,##0.00', 'en');

  @override
  Widget build(BuildContext context) {
    final totals = StatementRange.totals(transactions);

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 72,
          height: 72,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(width: 72, height: 72),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context, 'app_title'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context, 'statement_title'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
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
    final headerStyle = const TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
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
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(5),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: const Color(0xFF12233A).withOpacity(0.06)),
            children: [
              _cell(AppLocalizations.of(context, 'date_label'), style: headerStyle),
              _cell(AppLocalizations.of(context, 'description_label'), style: headerStyle),
              _cell(AppLocalizations.of(context, 'type_label'), style: headerStyle),
              _cell(AppLocalizations.of(context, 'amount_label'), style: headerStyle),
            ],
          ),
          for (final t in transactions)
            TableRow(
              children: [
                _cell(_formatDate(t['date'])),
                _cell(t['description'] as String? ?? t['fileName'] as String? ?? ''),
                _cell(AppLocalizations.of(
                  context,
                  t['type'] == 'income' ? 'income_label' : 'expense_label',
                )),
                _cell(_formatAmount(t['amount'])),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(String text, {TextStyle? style}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: Text(text, style: style),
      );

  Widget _totals(BuildContext context, Map<String, double> totals) {
    Widget line(String key, double value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context, key),
                  style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_money.format(value)} \$',
                style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          ),
        );

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: SizedBox(
        width: 280,
        child: Column(
          children: [
            line('incoming', totals['totalIncome'] ?? 0),
            line('outgoing', totals['totalExpense'] ?? 0),
            Divider(color: const Color(0xFF12233A).withOpacity(0.2)),
            line('balance_current', totals['balance'] ?? 0, bold: true),
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
        Image.asset(
          'assets/images/stamp.png',
          width: 110,
          height: 110,
          fit: BoxFit.contain,
          // A statement without the seal is better than one that invents it.
          errorBuilder: (_, __, ___) => const SizedBox(width: 110, height: 110),
        ),
      ],
    );
  }

  static String _formatDate(Object? raw) {
    final parsed = StatementRange.parseDate(raw);
    return parsed == null ? '' : _date.format(parsed);
  }

  static String _formatAmount(Object? raw) {
    final value = switch (raw) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };
    return value == null ? '' : _money.format(value);
  }
}
