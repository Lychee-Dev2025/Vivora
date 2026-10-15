class ActivityDateRange {
  const ActivityDateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

/// Local-calendar-day helpers.
///
/// The authoritative identity of a daily record is its **local calendar day**,
/// encoded in the Firestore document id (`yyyy_MM_dd` for activity logs,
/// `yyyy-MM-dd` for productivity logs). Timestamps stored in documents are only
/// used for ordering; the day is always read back from the id, so a device that
/// changes timezone, or documents written under an older convention, still map to
/// the right day.
class ActivityDateUtils {
  const ActivityDateUtils._();

  static String documentIdFor(DateTime date) => _key(date, '_');

  /// `yyyy-MM-dd`, the id scheme of `users/{uid}/dailyLogs`.
  static String dayKey(DateTime date) => _key(date, '-');

  static String _key(DateTime date, String separator) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '${localDate.year}$separator$month$separator$day';
  }

  /// Parses `yyyy_MM_dd` or `yyyy-MM-dd` back to local midnight.
  static DateTime? parseKey(String? key) {
    if (key == null) {
      return null;
    }
    final match = RegExp(r'^(\d{4})[-_](\d{2})[-_](\d{2})$').firstMatch(key);
    if (match == null) {
      return null;
    }
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  static DateTime dayStart(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    return DateTime(localDate.year, localDate.month, localDate.day);
  }

  /// Start of the next local day. Using the next midnight (rather than
  /// 23:59:59.999) keeps the window half-open and correct on DST days.
  static DateTime nextDayStart(DateTime date) {
    final start = dayStart(date);
    return DateTime(start.year, start.month, start.day + 1);
  }

  static ActivityDateRange currentDayRange(DateTime date) {
    return ActivityDateRange(start: dayStart(date), end: nextDayStart(date));
  }

  static bool isSameDay(DateTime left, DateTime right) {
    return documentIdFor(left) == documentIdFor(right);
  }

  /// The last [count] local days ending with [today], oldest first.
  static List<DateTime> lastDays(DateTime today, int count) {
    final end = dayStart(today);
    return List<DateTime>.generate(
      count,
      (int index) =>
          DateTime(end.year, end.month, end.day - (count - 1 - index)),
    );
  }
}
