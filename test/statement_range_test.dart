import 'package:flutter_test/flutter_test.dart';
import 'package:be_human_app/features/finance/domain/statement_range.dart';

void main() {
  Map<String, dynamic> tx(String date, {String type = 'income', Object? amount = 10}) =>
      {'date': date, 'type': type, 'amount': amount};

  group('StatementRange.contains', () {
    final range = StatementRange(
      from: DateTime(2026, 3, 1),
      to: DateTime(2026, 3, 31),
    );

    test('includes both ends of the range', () {
      expect(range.contains('2026-03-01T00:00:00.000'), isTrue);
      // A movement late on the closing day belongs to a statement that runs
      // "up to" that date.
      expect(range.contains('2026-03-31T18:30:00.000'), isTrue);
    });

    test('excludes dates outside it', () {
      expect(range.contains('2026-02-28T23:59:59.000'), isFalse);
      expect(range.contains('2026-04-01T00:00:00.000'), isFalse);
    });

    test('drops rows whose date is missing or unparseable', () {
      // One bad row must not take the whole statement down.
      expect(range.contains(null), isFalse);
      expect(range.contains(''), isFalse);
      expect(range.contains('not a date'), isFalse);
      expect(range.contains(20260315), isFalse);
    });
  });

  group('StatementRange.filter', () {
    test('keeps only the movements inside the period', () {
      final range = StatementRange(from: DateTime(2026, 3, 1), to: DateTime(2026, 3, 31));
      final filtered = range.filter([
        tx('2026-02-20T10:00:00.000'),
        tx('2026-03-05T10:00:00.000'),
        tx('2026-03-31T22:00:00.000'),
        tx('2026-04-02T10:00:00.000'),
        tx('broken'),
      ]);

      expect(filtered, hasLength(2));
    });
  });

  group('StatementRange.totals', () {
    test('separates income from expense and derives the balance', () {
      final totals = StatementRange.totals([
        tx('2026-03-01', type: 'income', amount: 1000),
        tx('2026-03-02', type: 'expense', amount: 250),
        tx('2026-03-03', type: 'expense', amount: 100.5),
      ]);

      expect(totals['totalIncome'], 1000);
      expect(totals['totalExpense'], 350.5);
      expect(totals['balance'], 649.5);
    });

    test('reads amounts stored as strings', () {
      final totals = StatementRange.totals([tx('2026-03-01', amount: '42.25')]);
      expect(totals['totalIncome'], 42.25);
    });

    test('treats an unusable amount as zero rather than throwing', () {
      final totals = StatementRange.totals([
        tx('2026-03-01', amount: null),
        tx('2026-03-02', amount: 'abc'),
        tx('2026-03-03', amount: 5),
      ]);
      expect(totals['totalIncome'], 5);
    });

    test('anything not marked income counts as expense', () {
      // Transactions are written with type 'income' or 'expense', but a row
      // with a missing type must not silently inflate the balance.
      final totals = StatementRange.totals([
        {'date': '2026-03-01', 'amount': 70},
      ]);
      expect(totals['totalExpense'], 70);
      expect(totals['balance'], -70);
    });
  });
}
