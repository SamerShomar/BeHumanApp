import 'package:flutter/widgets.dart';

import 'package:be_human_app/core/languages/app_localizations.dart';

/// A proposal's review state.
///
/// Stored as a stable key rather than a translated word. Earlier documents put
/// the Arabic label straight into Firestore, which meant the English and Dutch
/// UI showed Arabic, and any logic testing the status compared against one
/// language's wording.
class ProposalStatus {
  const ProposalStatus._();

  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';

  /// Maps whatever is on the document to a key, tolerating the Arabic labels
  /// written before this existed. Anything unrecognised is treated as pending,
  /// which is the state that grants the fewest rights.
  static String normalize(Object? raw) {
    final value = raw is String ? raw.trim() : '';
    return switch (value) {
      pending || 'معلق' || 'In afwachting' || 'Pending' => pending,
      accepted || 'مقبول' || 'Geaccepteerd' || 'Accepted' => accepted,
      rejected || 'مرفوض' || 'Geweigerd' || 'Rejected' => rejected,
      _ => pending,
    };
  }

  static bool isPending(Object? raw) => normalize(raw) == pending;

  /// The status in the reader's language.
  static String label(BuildContext context, Object? raw) =>
      AppLocalizations.of(context, normalize(raw));
}
