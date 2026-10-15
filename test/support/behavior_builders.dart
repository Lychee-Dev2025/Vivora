import 'package:vivora/features/activity_monitoring/data/models/app_usage_entry.dart';
import 'package:vivora/features/activity_monitoring/data/models/daily_activity_log.dart';
import 'package:vivora/features/first_time_setup/data/models/user_profile_model.dart';
import 'package:vivora/features/focus_mode/data/focus_session_repository.dart';
import 'package:vivora/features/insights/data/history_data.dart';
import 'package:vivora/features/productivity_scoring/data/models/productivity_models.dart';

/// Synthetic, test-only records for Module 3 scenarios. "Now" is fixed so
/// results are deterministic: Thursday 15 Oct 2026, 18:00 local.
final DateTime bNow = DateTime(2026, 10, 15, 18);

DateTime bDay(int daysAgo, [int hour = 0, int minute = 0]) =>
    DateTime(bNow.year, bNow.month, bNow.day - daysAgo, hour, minute);

SavedDailyScore bLog(
  int daysAgo, {
  double? sleep,
  double? study,
  double? focus,
  double? screen,
  double? routine,
  double? activity,
  double? score,
}) {
  final String? level = score == null
      ? null
      : score >= 85
      ? 'Excellent'
      : score >= 70
      ? 'Good'
      : score >= 50
      ? 'Medium'
      : 'Needs Improvement';
  return SavedDailyScore(
    log: DailyProductivityLog(
      date: bDay(daysAgo),
      actualSleepHours: sleep,
      actualStudyHours: study,
      actualFocusHours: focus,
      actualScreenTimeHours: screen,
      consistencyScore: routine,
      activityScore: activity,
    ),
    overallScore: score,
    performanceLevel: level,
    feedbackMessage: null,
    suggestions: const <String>[],
    coverage: 1,
    missingComponents: const <String>[],
    componentScores: const <String, double?>{},
  );
}

AppUsageEntry bApp(
  String pkg,
  String name,
  double minutes,
  AppCategory category,
) => AppUsageEntry(
  packageName: pkg,
  appName: name,
  usageMinutes: minutes.round(),
  foregroundDuration: Duration(milliseconds: (minutes * 60000).round()),
  lastUsedAt: null,
  category: category,
  isSystemApp: false,
);

DailyActivityLog bActivity(
  int daysAgo, {
  int? app,
  int? unlocked,
  int? unlocks,
  List<AppUsageEntry>? apps,
  int? walking,
  DateTime? syncedAt,
}) {
  return DailyActivityLog(
    date: bDay(daysAgo),
    appUsageMinutes: app,
    screenTimeMinutes: unlocked ?? (app == null ? null : app + 20),
    phoneUnlockCount: unlocks,
    appSummary: apps,
    movementStatus: walking == null ? 'noSamples' : 'available',
    walkingMinutes: walking,
    runningMinutes: walking == null ? null : 0,
    lastSyncAt: syncedAt ?? bDay(daysAgo, 23),
  );
}

FocusSession bSession(
  int daysAgo,
  int hour,
  int minutes, {
  bool completed = true,
  String? id,
}) {
  final DateTime start = bDay(daysAgo, hour);
  return FocusSession(
    id: id,
    startedAt: start,
    endedAt: start.add(Duration(minutes: minutes)),
    plannedMinutes: minutes,
    focusedSeconds: minutes * 60,
    completed: completed,
  );
}

final UserGoals bGoals = UserGoals(
  targetSleepHours: '8h',
  targetStudyHours: '3h',
  targetFocusHours: '2h',
  targetScreenTimeLimit: '3h',
);

HistoryData bHistory({
  List<SavedDailyScore> logs = const <SavedDailyScore>[],
  List<DailyActivityLog> activity = const <DailyActivityLog>[],
  List<FocusSession> sessions = const <FocusSession>[],
  UserGoals? goals,
  Map<String, AppCategory> overrides = const <String, AppCategory>{},
  DateTime? now,
}) {
  return HistoryData(
    today: now ?? bNow,
    activityLogs: activity,
    appUsageByDay: const <String, List<AppUsageEntry>>{},
    scores: logs,
    focusSessions: sessions,
    goals: goals,
    categoryOverrides: overrides,
  );
}
