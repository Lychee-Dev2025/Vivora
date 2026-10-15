import '../../activity_monitoring/data/models/activity_date_utils.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../../activity_monitoring/data/models/daily_activity_log.dart';
import '../../focus_mode/data/focus_session_repository.dart';
import '../../insights/data/history_data.dart';
import '../../productivity_scoring/data/models/productivity_models.dart';

/// One app on one day, after validation and with the user's category applied.
class AppDay {
  const AppDay({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.categoryIsUserChoice,
    required this.minutes,
  });

  final String packageName;
  final String appName;
  final AppCategory category;
  final bool categoryIsUserChoice;
  final double minutes;
}

/// Everything known about one local calendar day, validated.
///
/// `null` always means "not recorded" and is never treated as zero.
class DayRecord {
  DayRecord(this.dayKey, this.date);

  final String dayKey;
  final DateTime date;

  // Self-reported (daily productivity log).
  bool hasLog = false;
  double? sleepHours;
  double? studyHours;
  double? deepFocusHours;
  double? loggedScreenHours;
  double? routineRating;
  double? activityRating;
  double? score;
  String? performanceLevel;

  // Measured (Android). Only complete (past) days are used for comparisons.
  bool hasMeasurement = false;
  bool measurementComplete = false;
  double? appUsageMinutes;
  double? screenUnlockedMinutes;
  double? unlocks;
  double? sensorActiveMinutes;
  List<AppDay>? apps;
  double? productiveMinutes;
  double? distractingMinutes;
  double? neutralMinutes;
  double? uncategorizedMinutes;

  // Tracked (Focus Mode).
  int focusSessions = 0;
  int completedFocusSessions = 0;
  double focusSessionMinutes = 0;
}

/// Validated, de-duplicated history keyed by local day.
class NormalizedHistory {
  NormalizedHistory({
    required this.today,
    required this.days,
    required this.focusSessions,
    required this.excluded,
    required this.warnings,
    required this.goals,
  });

  final DateTime today;

  /// dayKey (`yyyy-MM-dd`) → record. Only days with at least one valid
  /// observation are present.
  final Map<String, DayRecord> days;

  /// Valid focus sessions, oldest first.
  final List<FocusSession> focusSessions;
  final Map<String, int> excluded;
  final List<String> warnings;
  final HistoryGoals goals;

  DayRecord? day(String key) => days[key];
}

/// Goals parsed once.
class HistoryGoals {
  const HistoryGoals({
    this.sleepHours,
    this.studyHours,
    this.focusHours,
    this.screenLimitHours,
  });
  final double? sleepHours;
  final double? studyHours;
  final double? focusHours;
  final double? screenLimitHours;
}

/// Turns raw repository data into trustworthy day records.
///
/// Rules (each exclusion is counted in [NormalizedHistory.excluded]):
///  * a record dated after today is dropped (`future_date`);
///  * two records for the same local day keep the most complete/latest one
///    (`duplicate_day`), so a day is never counted twice;
///  * hours outside 0–24, ratings/scores outside 0–100, minutes outside
///    0–1440, NaN or infinity are dropped individually (`invalid_value`);
///  * measured app usage clearly above screen-unlocked time is flagged as a
///    source conflict and that day's measurement is not used
///    (`conflicting_sources`);
///  * today's measurement is kept for the daily view but marked incomplete;
///  * focus sessions with end before start, negative/oversized durations,
///    future starts or duplicates are dropped; overlapping sessions are merged
///    so time is not counted twice.
class HistoryNormalizer {
  const HistoryNormalizer();

  NormalizedHistory normalize(HistoryData history) {
    final DateTime today = ActivityDateUtils.dayStart(history.today);
    final String todayKey = ActivityDateUtils.dayKey(today);
    final Map<String, DayRecord> days = <String, DayRecord>{};
    final Map<String, int> excluded = <String, int>{};
    final List<String> warnings = <String>[];

    void drop(String reason) => excluded[reason] = (excluded[reason] ?? 0) + 1;
    DayRecord record(DateTime date) {
      final String key = ActivityDateUtils.dayKey(date);
      return days.putIfAbsent(
        key,
        () => DayRecord(key, ActivityDateUtils.dayStart(date)),
      );
    }

    double? hours(double? v) {
      if (v == null) return null;
      if (v.isNaN || v.isInfinite || v < 0 || v > 24) {
        drop('invalid_value');
        return null;
      }
      return v;
    }

    double? rating(double? v) {
      if (v == null) return null;
      if (v.isNaN || v.isInfinite || v < 0 || v > 100) {
        drop('invalid_value');
        return null;
      }
      return v;
    }

    double? minutes(num? v, {double max = 1440}) {
      if (v == null) return null;
      final double d = v.toDouble();
      if (d.isNaN || d.isInfinite || d < 0 || d > max) {
        drop('invalid_value');
        return null;
      }
      return d;
    }

    // --- Self-reported daily logs -------------------------------------------
    final Set<String> seenLogs = <String>{};
    for (final SavedDailyScore score in history.scores) {
      final DateTime date = ActivityDateUtils.dayStart(score.date);
      if (date.isAfter(today)) {
        drop('future_date');
        continue;
      }
      final String key = ActivityDateUtils.dayKey(date);
      if (!seenLogs.add(key)) {
        drop('duplicate_day');
        continue;
      }
      final DayRecord r = record(date);
      final DailyProductivityLog log = score.log;
      r
        ..sleepHours = hours(log.actualSleepHours)
        ..studyHours = hours(log.actualStudyHours)
        ..deepFocusHours = hours(log.actualFocusHours)
        ..loggedScreenHours = hours(log.actualScreenTimeHours)
        ..routineRating = rating(log.consistencyScore)
        ..activityRating = rating(log.activityScore)
        ..score = rating(score.overallScore)
        ..performanceLevel = score.performanceLevel;
      r.hasLog =
          r.score != null ||
          r.sleepHours != null ||
          r.studyHours != null ||
          r.deepFocusHours != null ||
          r.loggedScreenHours != null ||
          r.routineRating != null ||
          r.activityRating != null;
    }

    // --- Measured activity --------------------------------------------------
    final Map<String, DailyActivityLog> latestActivity =
        <String, DailyActivityLog>{};
    for (final DailyActivityLog log in history.activityLogs) {
      final DateTime date = ActivityDateUtils.dayStart(log.date);
      if (date.isAfter(today)) {
        drop('future_date');
        continue;
      }
      final String key = ActivityDateUtils.dayKey(date);
      final DailyActivityLog? existing = latestActivity[key];
      if (existing != null) {
        drop('duplicate_day');
        final DateTime a = existing.lastSyncAt ?? DateTime(0);
        final DateTime b = log.lastSyncAt ?? DateTime(0);
        if (!b.isAfter(a)) continue;
      }
      latestActivity[key] = log;
    }
    for (final MapEntry<String, DailyActivityLog> entry
        in latestActivity.entries) {
      final DailyActivityLog log = entry.value;
      final DayRecord r = record(log.date);
      final double? app = minutes(log.appUsageMinutes);
      final double? unlocked = minutes(log.screenTimeMinutes);
      // App usage is the union of foreground apps, which can only exceed
      // unlocked screen time by small amounts (apps shown over the lock
      // screen, rounding). A large excess means one source is wrong.
      if (app != null && unlocked != null && app > unlocked * 1.15 + 15) {
        drop('conflicting_sources');
        warnings.add(
          'Measured data for ${entry.key} was not used: app usage '
          '(${app.round()} min) exceeds unlocked screen time (${unlocked.round()} min).',
        );
        continue;
      }
      r
        ..hasMeasurement = app != null || unlocked != null
        ..measurementComplete = entry.key != todayKey
        ..appUsageMinutes = app
        ..screenUnlockedMinutes = unlocked
        ..unlocks = minutes(log.phoneUnlockCount, max: 5000)
        ..sensorActiveMinutes = log.hasMovementData
            ? minutes(log.activeMinutes)
            : null;

      final List<AppUsageEntry>? rawApps =
          history.appUsageByDay[ActivityDateUtils.dayKey(log.date)] ??
          log.appSummary;
      if (rawApps != null) {
        final Map<String, AppDay> apps = <String, AppDay>{};
        for (final AppUsageEntry e in rawApps) {
          final double? m = minutes(
            e.foregroundDuration.inMilliseconds / 60000,
          );
          if (m == null || e.packageName.isEmpty) continue;
          if (apps.containsKey(e.packageName)) {
            drop('duplicate_app_entry');
            continue;
          }
          final AppCategory? override =
              history.categoryOverrides[e.packageName];
          apps[e.packageName] = AppDay(
            packageName: e.packageName,
            appName: e.displayName,
            category: override ?? e.category,
            categoryIsUserChoice: override != null || e.categoryIsUserOverride,
            minutes: m,
          );
        }
        r.apps = apps.values.toList();
        double sum(AppCategory c) => r.apps!
            .where((a) => a.category == c)
            .fold<double>(0, (s, a) => s + a.minutes);
        // Recomputed from app entries so later category changes apply.
        r
          ..productiveMinutes = sum(AppCategory.productive)
          ..distractingMinutes = sum(AppCategory.distracting)
          ..neutralMinutes = sum(AppCategory.neutral)
          ..uncategorizedMinutes = sum(AppCategory.uncategorized);
      } else {
        r
          ..productiveMinutes = minutes(log.productiveAppMinutes)
          ..distractingMinutes = minutes(log.distractingAppMinutes)
          ..neutralMinutes = minutes(log.neutralAppMinutes)
          ..uncategorizedMinutes = minutes(log.uncategorizedAppMinutes);
      }
    }

    // --- Focus sessions -----------------------------------------------------
    final DateTime now = history.today;
    final Set<String> seenSessions = <String>{};
    final List<FocusSession> sessions = <FocusSession>[];
    for (final FocusSession s in history.focusSessions) {
      final Duration span = s.endedAt.difference(s.startedAt);
      if (s.startedAt.isAfter(now)) {
        drop('future_date');
        continue;
      }
      if (span.isNegative ||
          s.focusedSeconds < 0 ||
          s.focusedSeconds > span.inSeconds + 60 ||
          span > const Duration(hours: 12)) {
        drop('invalid_session');
        continue;
      }
      final String id = s.id ?? '${s.startedAt.millisecondsSinceEpoch}';
      if (!seenSessions.add(id) ||
          !seenSessions.add('t${s.startedAt.millisecondsSinceEpoch}')) {
        drop('duplicate_session');
        continue;
      }
      sessions.add(s);
    }
    sessions.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    DateTime? coveredUntil;
    for (final FocusSession s in sessions) {
      // Overlap with an earlier session is not counted twice.
      double focused = s.focusedSeconds / 60;
      if (coveredUntil != null && s.startedAt.isBefore(coveredUntil)) {
        final double overlap =
            coveredUntil.difference(s.startedAt).inSeconds / 60;
        focused = (focused - overlap).clamp(0, focused).toDouble();
        drop('overlapping_session_time');
      }
      if (coveredUntil == null || s.endedAt.isAfter(coveredUntil)) {
        coveredUntil = s.endedAt;
      }
      final DayRecord r = record(s.startedAt);
      r
        ..focusSessions += 1
        ..completedFocusSessions += s.completed ? 1 : 0
        ..focusSessionMinutes += focused;
    }

    final UserGoalsParser goals = UserGoalsParser(history);
    return NormalizedHistory(
      today: today,
      days: days,
      focusSessions: sessions,
      excluded: excluded,
      warnings: warnings,
      goals: goals.parse(),
    );
  }
}

class UserGoalsParser {
  const UserGoalsParser(this.history);
  final HistoryData history;

  HistoryGoals parse() {
    double? h(String? text) {
      if (text == null) return null;
      final RegExpMatch? m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
      final double? v = m == null ? null : double.tryParse(m.group(1)!);
      return v == null || v <= 0 || v > 24 ? null : v;
    }

    final goals = history.goals;
    return HistoryGoals(
      sleepHours: h(goals?.targetSleepHours),
      studyHours: h(goals?.targetStudyHours),
      focusHours: h(goals?.targetFocusHours),
      screenLimitHours: h(goals?.targetScreenTimeLimit),
    );
  }
}
