import '../../activity_monitoring/data/models/activity_date_utils.dart';
import '../../activity_monitoring/data/models/daily_activity_log.dart';
import '../../productivity_scoring/data/models/productivity_models.dart';
import 'models/analytics_models.dart';

/// Averages over the days that actually have records in a period.
class PeriodSummary {
  const PeriodSummary({
    required this.days,
    required this.loggedDays,
    required this.measuredDays,
    this.averageScore,
    this.averageSleepHours,
    this.averageFocusHours,
    this.averageAppUsageMinutes,
    this.topDay,
  });

  /// Length of the period in days.
  final int days;

  /// Days with a saved productivity log.
  final int loggedDays;

  /// Days with measured app usage.
  final int measuredDays;
  final double? averageScore;
  final double? averageSleepHours;
  final double? averageFocusHours;
  final double? averageAppUsageMinutes;
  final TopDay? topDay;

  static PeriodSummary of({
    required List<SavedDailyScore> scores,
    required List<DailyActivityLog> activity,
    required DateTime today,
    required int days,
  }) {
    final Set<String> window = ActivityDateUtils.lastDays(
      today,
      days,
    ).map(ActivityDateUtils.dayKey).toSet();
    final List<SavedDailyScore> s = scores
        .where((x) => window.contains(ActivityDateUtils.dayKey(x.date)))
        .toList();
    final List<DailyActivityLog> a = activity
        .where(
          (x) =>
              x.appUsageMinutes != null &&
              window.contains(ActivityDateUtils.dayKey(x.date)),
        )
        .toList();
    double? avg(Iterable<double?> values) {
      final List<double> list = values.whereType<double>().toList();
      return list.isEmpty ? null : list.reduce((x, y) => x + y) / list.length;
    }

    return PeriodSummary(
      days: days,
      loggedDays: s.length,
      measuredDays: a.length,
      averageScore: avg(s.map((x) => x.overallScore)),
      averageSleepHours: avg(s.map((x) => x.log.actualSleepHours)),
      averageFocusHours: avg(s.map((x) => x.log.actualFocusHours)),
      averageAppUsageMinutes: avg(a.map((x) => x.appUsageMinutes!.toDouble())),
      topDay: AnalyticsCalculator.topDay(s),
    );
  }
}

class TopDay {
  const TopDay({required this.date, required this.score, required this.tied});
  final DateTime date;
  final double score;

  /// True when another day had the same (rounded) score; the most recent wins.
  final bool tied;
}

/// Pure calculations behind the Analytics and Reports screens. Inputs are the
/// saved records only; days without records produce no points.
class AnalyticsCalculator {
  const AnalyticsCalculator._();

  static const List<String> weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Saved scores within the last [days] days, oldest first, labelled by
  /// weekday (unique within a 7-day window).
  static List<ChartDataPoint> scorePoints(
    List<SavedDailyScore> scores,
    DateTime today, {
    int days = 7,
  }) {
    final Set<String> window = ActivityDateUtils.lastDays(
      today,
      days,
    ).map(ActivityDateUtils.dayKey).toSet();
    final List<SavedDailyScore> inWindow =
        scores
            .where(
              (s) =>
                  s.overallScore != null &&
                  window.contains(ActivityDateUtils.dayKey(s.date)),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return inWindow
        .map((s) => ChartDataPoint(_label(s.date, days), s.overallScore!))
        .toList();
  }

  static List<ChartDataPoint> sleepPoints(
    List<SavedDailyScore> scores,
    DateTime today, {
    int days = 7,
  }) {
    final Set<String> window = ActivityDateUtils.lastDays(
      today,
      days,
    ).map(ActivityDateUtils.dayKey).toSet();
    final List<SavedDailyScore> inWindow =
        scores
            .where(
              (s) =>
                  s.log.actualSleepHours != null &&
                  window.contains(ActivityDateUtils.dayKey(s.date)),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return inWindow
        .map(
          (s) => ChartDataPoint(_label(s.date, days), s.log.actualSleepHours!),
        )
        .toList();
  }

  /// Measured app usage per day, in minutes.
  static List<ChartDataPoint> appUsagePoints(
    List<DailyActivityLog> logs,
    DateTime today, {
    int days = 7,
  }) {
    final Set<String> window = ActivityDateUtils.lastDays(
      today,
      days,
    ).map(ActivityDateUtils.dayKey).toSet();
    final List<DailyActivityLog> inWindow =
        logs
            .where(
              (l) =>
                  l.appUsageMinutes != null &&
                  window.contains(ActivityDateUtils.dayKey(l.date)),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return inWindow
        .map(
          (l) => ChartDataPoint(
            _label(l.date, days),
            l.appUsageMinutes!.toDouble(),
          ),
        )
        .toList();
  }

  /// Productive vs distracting app minutes for one day. Neutral and
  /// uncategorized apps are deliberately excluded: this ratio describes how
  /// *categorised* app time splits, not "focused work".
  static List<ChartDataPoint> appFocusRatio(DailyActivityLog? log) {
    return <ChartDataPoint>[
      ChartDataPoint('Productive', (log?.productiveAppMinutes ?? 0).toDouble()),
      ChartDataPoint(
        'Distracting',
        (log?.distractingAppMinutes ?? 0).toDouble(),
      ),
    ];
  }

  /// Highest-scoring day; null with fewer than two scored days (a single day is
  /// trivially the "top" and says nothing).
  static TopDay? topDay(List<SavedDailyScore> scores) {
    final List<SavedDailyScore> scored =
        scores.where((s) => s.overallScore != null).toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (scored.length < 2) {
      return null;
    }
    SavedDailyScore best = scored.first;
    bool tied = false;
    for (final SavedDailyScore s in scored.skip(1)) {
      final int current = s.overallScore!.round();
      final int top = best.overallScore!.round();
      if (current > top) {
        best = s;
        tied = false;
      } else if (current == top) {
        best = s; // most recent wins
        tied = true;
      }
    }
    return TopDay(date: best.date, score: best.overallScore!, tied: tied);
  }

  /// Longest run of consecutive calendar days with a saved score.
  static int bestStreak(List<SavedDailyScore> scores) {
    final List<DateTime> days = _scoredDays(scores);
    int best = 0;
    int run = 0;
    DateTime? previous;
    for (final DateTime day in days) {
      run = previous != null && _isNextDay(previous, day) ? run + 1 : 1;
      if (run > best) best = run;
      previous = day;
    }
    return best;
  }

  /// Consecutive days with a score ending today (or yesterday, if today has
  /// not been logged yet).
  static int currentStreak(List<SavedDailyScore> scores, DateTime today) {
    final Set<String> keys = _scoredDays(
      scores,
    ).map(ActivityDateUtils.dayKey).toSet();
    DateTime cursor = ActivityDateUtils.dayStart(today);
    if (!keys.contains(ActivityDateUtils.dayKey(cursor))) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    int streak = 0;
    while (keys.contains(ActivityDateUtils.dayKey(cursor))) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  static List<DateTime> _scoredDays(List<SavedDailyScore> scores) {
    final Map<String, DateTime> unique = <String, DateTime>{};
    for (final SavedDailyScore s in scores) {
      if (s.overallScore != null) {
        unique[ActivityDateUtils.dayKey(s.date)] = ActivityDateUtils.dayStart(
          s.date,
        );
      }
    }
    return unique.values.toList()..sort();
  }

  static bool _isNextDay(DateTime a, DateTime b) {
    final DateTime next = DateTime(a.year, a.month, a.day + 1);
    return ActivityDateUtils.dayKey(next) == ActivityDateUtils.dayKey(b);
  }

  static String _label(DateTime date, int days) {
    if (days <= 7) {
      return weekdays[date.weekday - 1];
    }
    return '${date.day}/${date.month}';
  }

  static String formatDate(DateTime date) =>
      '${weekdays[date.weekday - 1]} ${date.day}/${date.month}';
}
