import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/features/finance/domain/statement_filter.dart';

void main() {
  Map<String, dynamic> row(
    String date, {
    double amount = 100,
    String currency = 'EUR',
    double? rate = 4.0,
  }) =>
      {
        'id': date,
        'type': 'expense',
        'date': date,
        'amount': amount,
        'currency': currency,
        if (rate != null) 'ilsPerEur': rate,
      };

  final ledger = [
    row('2026-01-15T10:00:00.000', amount: 50),
    row('2026-03-20T10:00:00.000', amount: 500),
    row('2026-06-01T18:30:00.000', amount: 5000),
  ];

  group('an empty filter', () {
    test('matches everything and is reported as empty', () {
      expect(StatementFilter.none.isEmpty, isTrue);
      expect(StatementFilter.none.apply(ledger), hasLength(3));
    });
  });

  group('dates', () {
    test('are inclusive on the last day', () {
      // A movement recorded at 18:30 belongs to a statement running "up to"
      // that date. Comparing raw DateTimes would drop it.
      final filter = StatementFilter(
        from: DateTime(2026, 6, 1),
        to: DateTime(2026, 6, 1),
      );
      expect(filter.apply(ledger), hasLength(1));
    });

    test('work with only one end set', () {
      expect(
        StatementFilter(from: DateTime(2026, 3, 1)).apply(ledger),
        hasLength(2),
      );
      expect(
        StatementFilter(to: DateTime(2026, 3, 1)).apply(ledger),
        hasLength(1),
      );
    });

    test('exclude a row whose date cannot be read', () {
      final broken = [
        ...ledger,
        {'id': 'x', 'date': 'not a date', 'amount': 100, 'currency': 'EUR'},
      ];
      final filter = StatementFilter(from: DateTime(2020), to: DateTime(2030));
      expect(filter.apply(broken), hasLength(3));
    });
  });

  group('amounts', () {
    test('bound the euro figure, whatever the row was entered in', () {
      // 2000 shekels at 4.0 is 500 euro, so it belongs in a 400–600 band even
      // though its stored amount is far outside it.
      final shekels = row('2026-02-01T10:00:00.000',
          amount: 2000, currency: 'ILS', rate: 4.0);
      final filter = const StatementFilter(minAmount: 400, maxAmount: 600);

      expect(filter.matches(shekels), isTrue);
      expect(filter.apply([...ledger, shekels]), hasLength(2));
    });

    test('work with only one bound set', () {
      expect(const StatementFilter(minAmount: 100).apply(ledger), hasLength(2));
      expect(const StatementFilter(maxAmount: 100).apply(ledger), hasLength(1));
    });

    test('exclude a row with no usable euro value', () {
      // An old entry with no exchange rate cannot be shown to fall between two
      // euro figures, so it is left out rather than converted at a rate nobody
      // chose — the same rule the statement's totals follow.
      final noRate = row('2026-02-01T10:00:00.000',
          amount: 300, currency: 'ILS', rate: null);
      expect(const StatementFilter(minAmount: 1).matches(noRate), isFalse);
      // …and is still shown when no amount bound is set at all.
      expect(StatementFilter(from: DateTime(2020)).matches(noRate), isTrue);
    });
  });

  test('dates and amounts combine', () {
    final filter = StatementFilter(
      from: DateTime(2026, 2, 1),
      minAmount: 1000,
    );
    expect(filter.apply(ledger).single['id'], '2026-06-01T18:30:00.000');
  });

  group('the period printed on the statement', () {
    test('uses the filter when it sets one', () {
      final filter = StatementFilter(
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );
      final range = filter.rangeFor(ledger);
      expect(range.from, DateTime(2026, 1, 1));
      expect(range.to, DateTime(2026, 12, 31));
    });

    test('falls back to the rows when the filter set no dates', () {
      // A statement always states a period; an amount-only filter still has to
      // print one, and the honest one is what the rows actually span.
      final range = const StatementFilter(minAmount: 10).rangeFor(ledger);
      expect(range.from, DateTime.parse('2026-01-15T10:00:00.000'));
      expect(range.to, DateTime.parse('2026-06-01T18:30:00.000'));
    });

    test('fills only the end the filter left open', () {
      final range = StatementFilter(from: DateTime(2026, 5, 1)).rangeFor(ledger);
      expect(range.from, DateTime(2026, 5, 1));
      expect(range.to, DateTime.parse('2026-06-01T18:30:00.000'));
    });
  });

  group('copyWith', () {
    test('clears one half without disturbing the other', () {
      final filter = StatementFilter(
        from: DateTime(2026, 1, 1),
        minAmount: 50,
      );
      expect(filter.copyWith(clearDates: true).hasDates, isFalse);
      expect(filter.copyWith(clearDates: true).minAmount, 50);
      expect(filter.copyWith(clearAmounts: true).hasAmounts, isFalse);
      expect(filter.copyWith(clearAmounts: true).from, DateTime(2026, 1, 1));
    });
  });
}
