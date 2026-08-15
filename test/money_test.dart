import 'package:flutter_test/flutter_test.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';
import 'package:be_human_app/features/finance/domain/money.dart';

/// The ledger is kept in two currencies: donations arrive in euro, spending
/// happens in shekel. Each movement records the currency it actually moved in
/// plus the rate on the day, and both columns are derived from that.
void main() {
  Map<String, dynamic> movement({
    required String type,
    required double amount,
    String? currency,
    double? rate,
  }) => {
        'type': type,
        'amount': amount,
        if (currency != null) 'currency': currency,
        if (rate != null) 'ilsPerEur': rate,
      };

  group('Money', () {
    test('converts a euro movement into shekels', () {
      final money = Money.fromTransaction(
        movement(type: 'income', amount: 1000, currency: 'EUR', rate: 4.0),
      );
      expect(money.eur, 1000);
      expect(money.ils, 4000);
      expect(money.isFullyConvertible, isTrue);
    });

    test('converts a shekel movement into euro', () {
      final money = Money.fromTransaction(
        movement(type: 'expense', amount: 4000, currency: 'ILS', rate: 4.0),
      );
      expect(money.ils, 4000);
      expect(money.eur, 1000);
    });

    test('never invents a rate that was not recorded', () {
      // The whole point: a printed financial record must not carry a figure
      // nobody chose a rate for.
      final money = Money.fromTransaction(
        movement(type: 'expense', amount: 500, currency: 'ILS'),
      );
      expect(money.ils, 500);
      expect(money.eur, isNull);
      expect(money.isFullyConvertible, isFalse);
      expect(money.formattedEur, '—');
    });

    test('reads a record written before currencies existed as shekels', () {
      // The ledger was kept in Gaza, so that is what those numbers were.
      final money = Money.fromTransaction({'type': 'expense', 'amount': 250});
      expect(money.currency, StatementCurrency.ils);
      expect(money.ils, 250);
      expect(money.eur, isNull);
    });

    test('refuses a zero or negative rate rather than dividing by it', () {
      final money = Money.fromTransaction(
        movement(type: 'income', amount: 100, currency: 'ILS', rate: 0),
      );
      expect(money.eur, isNull);
    });

    test('accepts the currency however it was written', () {
      for (final raw in ['EUR', 'eur', '€', 'Euro']) {
        expect(StatementCurrency.parse(raw), StatementCurrency.eur);
      }
      for (final raw in ['ILS', 'ils', '₪', 'shekel']) {
        expect(StatementCurrency.parse(raw), StatementCurrency.ils);
      }
      expect(StatementCurrency.parse('USD'), isNull);
    });
  });

  group('MoneyTotals', () {
    test('totals both columns and the balance', () {
      final totals = MoneyTotals.of([
        movement(type: 'income', amount: 1000, currency: 'EUR', rate: 4.0),
        movement(type: 'expense', amount: 2000, currency: 'ILS', rate: 4.0),
      ]);

      expect(totals.incomeEur, 1000);
      expect(totals.incomeIls, 4000);
      expect(totals.expenseIls, 2000);
      expect(totals.expenseEur, 500);
      expect(totals.balanceIls, 2000);
      expect(totals.balanceEur, 500);
      expect(totals.isIlsComplete, isTrue);
      expect(totals.isEurComplete, isTrue);
    });

    test('counts what it could not convert instead of hiding it', () {
      // A total that quietly omits rows is worse than one that says how many
      // it left out.
      final totals = MoneyTotals.of([
        movement(type: 'income', amount: 1000, currency: 'EUR', rate: 4.0),
        movement(type: 'expense', amount: 300, currency: 'ILS'),
      ]);

      // Counted per currency: the shekel column is whole — that row was
      // entered in shekels — and only the euro one is short.
      expect(totals.missingIls, 0);
      expect(totals.isIlsComplete, isTrue);
      expect(totals.missingEur, 1);
      expect(totals.isEurComplete, isFalse);
      expect(totals.expenseIls, 300);
      expect(totals.expenseEur, 0);
    });

    test('an empty ledger totals to nothing, not to an error', () {
      final totals = MoneyTotals.of(const []);
      expect(totals.balanceIls, 0);
      expect(totals.balanceEur, 0);
      expect(totals.isIlsComplete, isTrue);
      expect(totals.isEurComplete, isTrue);
    });
  });

  group('formatting', () {
    test('carries the symbol and thousands separators', () {
      expect(Money.format(15349.5, StatementCurrency.ils), '15,349.50 ₪');
      expect(Money.format(1250, StatementCurrency.eur), '1,250.00 €');
    });

    test('shows an em dash rather than a zero for an unknown value', () {
      expect(Money.format(null, StatementCurrency.eur), '—');
    });
  });

  group('translations', () {
    test('every new key exists in all three languages', () {
      const keys = [
        'invoices_title', 'currency_label', 'currency_ils', 'currency_eur',
        'amount_ils', 'amount_eur', 'exchange_rate_label', 'exchange_rate_help',
        'invalid_rate', 'equals_value', 'transfer_receipt', 'receipt_required',
        'receipt_required_hint', 'view_receipt', 'no_receipt_on_record',
        'totals_missing_rate',
      ];
      for (final locale in AppLocalizations.supportedLocales) {
        for (final key in keys) {
          expect(AppLocalizations.translate(locale, key), isNot(key),
              reason: 'Missing "$key" in ${locale.languageCode}');
        }
      }
    });
  });
}
