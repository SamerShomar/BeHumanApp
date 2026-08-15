import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';

/// The two currencies the foundation actually works in: donations arrive in
/// euro, spending happens in shekel.
enum StatementCurrency {
  ils('ILS', '₪'),
  eur('EUR', '€');

  const StatementCurrency(this.code, this.symbol);

  final String code;
  final String symbol;

  String label(BuildContext context) =>
      AppLocalizations.of(context, 'currency_$name');

  static StatementCurrency? parse(Object? raw) {
    final value = '${raw ?? ''}'.trim().toUpperCase();
    return switch (value) {
      'ILS' || '₪' || 'SHEKEL' => StatementCurrency.ils,
      'EUR' || '€' || 'EURO' => StatementCurrency.eur,
      _ => null,
    };
  }
}

/// One amount, recorded in the currency it was actually moved in, plus the
/// rate that lets it be read in the other one.
///
/// A single rate is stored rather than two, because there is only one number
/// a person can honestly know at the moment of a transfer: what a euro was
/// worth in shekels that day. Both columns of the statement come from it.
class Money {
  const Money({
    required this.amount,
    required this.currency,
    this.ilsPerEur,
  });

  final double amount;
  final StatementCurrency currency;

  /// How many shekels one euro bought, as entered by whoever recorded the
  /// movement. Null on records written before the app asked for it.
  final double? ilsPerEur;

  /// The value in shekels, or null when it cannot be derived honestly.
  double? get ils => switch (currency) {
        StatementCurrency.ils => amount,
        StatementCurrency.eur => ilsPerEur == null ? null : amount * ilsPerEur!,
      };

  /// The value in euro, or null when it cannot be derived honestly.
  ///
  /// Never invented: an old record with no rate reads as unknown rather than
  /// being converted at some rate nobody chose.
  double? get eur => switch (currency) {
        StatementCurrency.eur => amount,
        StatementCurrency.ils =>
          (ilsPerEur == null || ilsPerEur == 0) ? null : amount / ilsPerEur!,
      };

  /// Whether both columns can be filled in for this movement.
  bool get isFullyConvertible => ils != null && eur != null;

  /// Reads a stored transaction.
  ///
  /// Records written before currencies existed carry only a number. They are
  /// read as shekels — which is what they were, the ledger having been kept in
  /// Gaza — with no rate, so they count toward the shekel total and are
  /// declared missing from the euro one rather than guessed at.
  static Money fromTransaction(Map<String, dynamic> transaction) {
    final amount = switch (transaction['amount']) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? 0.0,
      _ => 0.0,
    };

    final rate = switch (transaction['ilsPerEur']) {
      final num n when n > 0 => n.toDouble(),
      final String s => double.tryParse(s),
      _ => null,
    };

    return Money(
      amount: amount,
      currency: StatementCurrency.parse(transaction['currency']) ??
          StatementCurrency.ils,
      ilsPerEur: (rate ?? 0) > 0 ? rate : null,
    );
  }

  static final NumberFormat _format = NumberFormat('#,##0.00', 'en');

  /// Formats a value in [currency], or an em dash when there is none.
  static String format(double? value, StatementCurrency currency) =>
      value == null ? '—' : '${_format.format(value)} ${currency.symbol}';

  String get formattedIls => format(ils, StatementCurrency.ils);
  String get formattedEur => format(eur, StatementCurrency.eur);

  /// The value with a leading sign, for a ledger row.
  ///
  /// An unknown value keeps its em dash and takes no sign: "+—" reads as a
  /// figure that went missing, which is not what it means.
  static String signed(double? value, StatementCurrency currency,
      {required bool isIncome}) {
    if (value == null) return format(null, currency);
    return '${isIncome ? '+' : '−'}${format(value, currency)}';
  }

  String signedIls({required bool isIncome}) =>
      signed(ils, StatementCurrency.ils, isIncome: isIncome);

  String signedEur({required bool isIncome}) =>
      signed(eur, StatementCurrency.eur, isIncome: isIncome);

  /// The amount as it was entered, in its own currency.
  String get formattedOriginal => format(amount, currency);
}

/// Both columns of a statement's totals.
class MoneyTotals {
  const MoneyTotals({
    required this.incomeIls,
    required this.incomeEur,
    required this.expenseIls,
    required this.expenseEur,
    required this.missingIls,
    required this.missingEur,
  });

  final double incomeIls;
  final double incomeEur;
  final double expenseIls;
  final double expenseEur;

  /// How many movements are missing from each column.
  ///
  /// Counted per currency because the two are read in different places: the
  /// printed statement is in shekels and the app is in euro, so a row that is
  /// short in one is not necessarily short in the other. Surfaced rather than
  /// swallowed — a total that quietly omits rows is worse than one that says
  /// how many it left out.
  final int missingIls;
  final int missingEur;

  double get balanceIls => incomeIls - expenseIls;
  double get balanceEur => incomeEur - expenseEur;

  bool get isIlsComplete => missingIls == 0;
  bool get isEurComplete => missingEur == 0;

  static MoneyTotals of(List<Map<String, dynamic>> transactions) {
    var incomeIls = 0.0;
    var incomeEur = 0.0;
    var expenseIls = 0.0;
    var expenseEur = 0.0;
    var missingIls = 0;
    var missingEur = 0;

    for (final transaction in transactions) {
      final money = Money.fromTransaction(transaction);
      if (money.ils == null) missingIls++;
      if (money.eur == null) missingEur++;

      final isIncome = transaction['type'] == 'income';
      if (isIncome) {
        incomeIls += money.ils ?? 0;
        incomeEur += money.eur ?? 0;
      } else {
        expenseIls += money.ils ?? 0;
        expenseEur += money.eur ?? 0;
      }
    }

    return MoneyTotals(
      incomeIls: incomeIls,
      incomeEur: incomeEur,
      expenseIls: expenseIls,
      expenseEur: expenseEur,
      missingIls: missingIls,
      missingEur: missingEur,
    );
  }
}
