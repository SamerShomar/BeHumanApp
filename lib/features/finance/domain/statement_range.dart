/// A closed date range and the movements that fall inside it.
///
/// Transactions store their date as an ISO-8601 string, so filtering has to
/// tolerate a malformed or missing value rather than throwing on one bad row.
class StatementRange {
  const StatementRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  /// Whether [raw] — an ISO-8601 string on a transaction — falls in range.
  ///
  /// Both ends are inclusive by day: a movement recorded at 18:00 on the `to`
  /// date belongs to a statement that runs "up to" that date.
  bool contains(Object? raw) {
    final date = parseDate(raw);
    if (date == null) return false;

    final start = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    return !date.isBefore(start) && !date.isAfter(end);
  }

  static DateTime? parseDate(Object? raw) =>
      raw is String ? DateTime.tryParse(raw) : null;

  List<Map<String, dynamic>> filter(List<Map<String, dynamic>> transactions) =>
      transactions.where((t) => contains(t['date'])).toList();

  /// Income, expense and balance for the movements in range.
  static Map<String, double> totals(List<Map<String, dynamic>> transactions) {
    var income = 0.0;
    var expense = 0.0;

    for (final t in transactions) {
      final amount = switch (t['amount']) {
        final num n => n.toDouble(),
        final String s => double.tryParse(s) ?? 0.0,
        _ => 0.0,
      };
      if (t['type'] == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    }

    return {
      'totalIncome': income,
      'totalExpense': expense,
      'balance': income - expense,
    };
  }
}
