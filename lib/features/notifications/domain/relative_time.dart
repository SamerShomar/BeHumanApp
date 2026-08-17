/// Turns a timestamp into "3 minutes ago" — as a translation key and its
/// parameters rather than a finished string, so the same logic works in all
/// three languages and can be tested without a widget tree.
abstract final class RelativeTime {
  static ({String key, Map<String, String> params}) describe(
    DateTime moment, {
    DateTime? now,
  }) {
    final elapsed = (now ?? DateTime.now()).difference(moment);

    // A clock skew between two phones can put an event slightly in the
    // future; showing "in -2 minutes" would be worse than "just now".
    if (elapsed.inMinutes < 1) {
      return (key: 'time_just_now', params: const {});
    }
    if (elapsed.inHours < 1) {
      return (key: 'time_minutes_ago', params: {'n': '${elapsed.inMinutes}'});
    }
    if (elapsed.inDays < 1) {
      return (key: 'time_hours_ago', params: {'n': '${elapsed.inHours}'});
    }
    return (key: 'time_days_ago', params: {'n': '${elapsed.inDays}'});
  }
}
