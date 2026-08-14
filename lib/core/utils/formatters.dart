import 'package:intl/intl.dart';

/// Display formatting, in one place.
///
/// The app previously printed the same figure three ways — `25000.0`,
/// `25,000$` and `25000.00$` — and showed stored ISO timestamps
/// (`2026-08-10T09:00:00.000`) straight to users. Both are fixed by everything
/// going through here.
abstract final class Formatters {
  /// Money, always with two decimals and thousands separators.
  ///
  /// Digits stay Western in every language: the team reads financial figures
  /// across Arabic, English and Dutch, and mixing numeral systems in a ledger
  /// invites mistakes.
  static String amount(Object? value) {
    final number = value is num ? value : num.tryParse('${value ?? ''}');
    if (number == null) return '—';
    return '${NumberFormat('#,##0.00', 'en').format(number)}\$';
  }

  /// The number alone, for text that supplies its own currency symbol —
  /// a notification body, for instance.
  static String plainAmount(Object? value) {
    final number = value is num ? value : num.tryParse('${value ?? ''}');
    if (number == null) return '—';
    return NumberFormat('#,##0.00', 'en').format(number);
  }

  /// The same figure with an explicit sign, for a ledger row.
  static String signedAmount(Object? value, {required bool isIncome}) {
    final number = value is num ? value : num.tryParse('${value ?? ''}');
    if (number == null) return '—';
    final magnitude = NumberFormat('#,##0.00', 'en').format(number.abs());
    return '${isIncome ? '+' : '−'}$magnitude\$';
  }

  /// A stored date as a day. Anything unparseable is returned untouched rather
  /// than blanked, so a malformed record is still recognisable.
  static String date(Object? value) {
    if (value is DateTime) return DateFormat('yyyy-MM-dd').format(value);
    if (value is! String || value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormat('yyyy-MM-dd').format(parsed);
  }

  /// A stored date with the time, for entries where the hour matters.
  static String dateTime(Object? value) {
    if (value is! String || value.isEmpty) return '';
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormat('yyyy-MM-dd  HH:mm').format(parsed);
  }
}
