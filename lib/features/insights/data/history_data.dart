import '../../activity_monitoring/data/models/activity_date_utils.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../../activity_monitoring/data/models/daily_activity_log.dart';
import '../../first_time_setup/data/models/user_profile_model.dart';
import '../../focus_mode/data/focus_session_repository.dart';
import '../../productivity_scoring/data/models/productivity_models.dart';

/// Recorded history for one user over a window of local days. Only real,
/// stored records are included; days without records are simply missing.
class HistoryData {
  const HistoryData({
    required this.today,
    required this.activityLogs,
    required this.appUsageByDay,
    required this.scores,
    required this.focusSessions,
    this.goals,
    this.categoryOverrides = const <String, AppCategory>{},
  });

  static HistoryData empty(DateTime today) => HistoryData(
    today: today,
    activityLogs: const <DailyActivityLog>[],
    appUsageByDay: const <String, List<AppUsageEntry>>{},
    scores: const <SavedDailyScore>[],
    focusSessions: const <FocusSession>[],
  );

  final DateTime today;

  /// Oldest first.
  final List<DailyActivityLog> activityLogs;

  /// Keyed by [ActivityDateUtils.dayKey].
  final Map<String, List<AppUsageEntry>> appUsageByDay;

  /// Oldest first.
  final List<SavedDailyScore> scores;

  /// Newest first.
  final List<FocusSession> focusSessions;
  final UserGoals? goals;

  /// Categories chosen by the user (package → category); they override the
  /// category stored with each day's capture.
  final Map<String, AppCategory> categoryOverrides;

  String get todayKey => ActivityDateUtils.dayKey(today);

  /// Activity logs with real app-usage measurements.
  List<DailyActivityLog> get measuredDays => activityLogs
      .where((DailyActivityLog log) => log.appUsageMinutes != null)
      .toList();

  /// Completed days only (today is still in progress and would skew averages).
  List<DailyActivityLog> get completedMeasuredDays => measuredDays
      .where(
        (DailyActivityLog log) =>
            ActivityDateUtils.dayKey(log.date) != todayKey,
      )
      .toList();

  SavedDailyScore? get todayScore {
    for (final SavedDailyScore score in scores) {
      if (ActivityDateUtils.dayKey(score.date) == todayKey) {
        return score;
      }
    }
    return null;
  }

  DailyActivityLog? get todayActivity {
    for (final DailyActivityLog log in activityLogs) {
      if (ActivityDateUtils.dayKey(log.date) == todayKey) {
        return log;
      }
    }
    return null;
  }

  HistoryData withToday({DailyActivityLog? log, List<AppUsageEntry>? apps}) {
    if (log == null) {
      return this;
    }
    final String key = ActivityDateUtils.dayKey(log.date);
    return HistoryData(
      today: today,
      activityLogs: <DailyActivityLog>[
        ...activityLogs.where((l) => ActivityDateUtils.dayKey(l.date) != key),
        log,
      ]..sort((a, b) => a.date.compareTo(b.date)),
      appUsageByDay: <String, List<AppUsageEntry>>{
        ...appUsageByDay,
        if (apps != null) key: apps,
      },
      scores: scores,
      focusSessions: focusSessions,
      goals: goals,
      categoryOverrides: categoryOverrides,
    );
  }
}
