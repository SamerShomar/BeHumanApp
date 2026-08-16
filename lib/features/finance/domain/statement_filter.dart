import 'package:be_human_app/features/finance/domain/money.dart';
import 'package:be_human_app/features/finance/domain/statement_range.dart';

/// What the ledger is narrowed to before it is read or printed.
///
/// Every part is optional and they combine: a filter with only an upper amount
/// is as valid as one with only a start date. An empty filter matches
/// everything, which is what the screen opens on.
class StatementFilter {
  const StatementFilter({this.from, this.to, this.minAmount, this.maxAmount});

  final DateTime? from;
  final DateTime? to;

  /// Bounds on the euro figure — the one shown on screen and in the second
  /// column of the statement. Filtering on the stored amount instead would
  /// compare a shekel entry against a euro one and silently mix the two.
  final double? minAmount;
  final double? maxAmount;

  static const StatementFilter none = StatementFilter();

  bool get isEmpty =>
      from == null && to == null && minAmount == null && maxAmount == null;

  bool get hasDates => from != null || to != null;
  bool get hasAmounts => minAmount != null || maxAmount != null;

  StatementFilter copyWith({
    DateTime? from,
    DateTime? to,
    double? minAmount,
    double? maxAmount,
    bool clearDates = false,
    bool clearAmounts = false,
  }) =>
      StatementFilter(
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
        minAmount: clearAmounts ? null : (minAmount ?? this.minAmount),
        maxAmount: clearAmounts ? null : (maxAmount ?? this.maxAmount),
      );

  bool matches(Map<String, dynamic> transaction) {
    if (from != null || to != null) {
      final date = StatementRange.parseDate(transaction['date']);
      // A row with no readable date cannot be shown to fall inside a period.
      if (date == null) return false;

      if (from != null) {
        final start = DateTime(from!.year, from!.month, from!.day);
        if (date.isBefore(start)) return false;
      }
      if (to != null) {
        // Inclusive by day: a movement recorded at 18:00 on the end date
        // belongs to a statement that runs "up to" that date.
        final end = DateTime(to!.year, to!.month, to!.day, 23, 59, 59, 999);
        if (date.isAfter(end)) return false;
      }
    }

    if (minAmount != null || maxAmount != null) {
      final euro = Money.fromTransaction(transaction).eur;
      // Unknown in euro — an old row with no exchange rate — cannot be said to
      // fall between two euro figures. Excluded rather than guessed at, which
      // is the same rule the statement's totals already follow.
      if (euro == null) return false;

      final magnitude = euro.abs();
      if (minAmount != null && magnitude < minAmount!) return false;
      if (maxAmount != null && magnitude > maxAmount!) return false;
    }

    return true;
  }

  List<Map<String, dynamic>> apply(List<Map<String, dynamic>> transactions) =>
      isEmpty ? transactions : transactions.where(matches).toList();

  /// The period to print in the statement header.
  ///
  /// A statement always states a period, even when the filter set no dates —
  /// so the gap is filled from the rows themselves rather than left blank or
  /// printed as today-to-today.
  StatementRange rangeFor(List<Map<String, dynamic>> transactions) {
    final dates = transactions
        .map((t) => StatementRange.parseDate(t['date']))
        .whereType<DateTime>()
        .toList()
      ..sort();

    final now = DateTime.now();
    return StatementRange(
      from: from ?? (dates.isEmpty ? now : dates.first),
      to: to ?? (dates.isEmpty ? now : dates.last),
    );
  }
}
