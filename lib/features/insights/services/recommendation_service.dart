import '../../activity_monitoring/data/models/activity_date_utils.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../../activity_monitoring/data/models/daily_activity_log.dart';
import '../../productivity_scoring/data/models/productivity_models.dart';
import '../../productivity_scoring/data/services/productivity_score_service.dart';
import '../data/history_data.dart';
import '../../behavior_analysis/domain/behavior_models.dart';

class Recommendation {
  const Recommendation({
    required this.id,
    required this.title,
    required this.action,
    required this.evidence,
    required this.priority,
  });

  final String id;
  final String title;

  /// What to do.
  final String action;

  /// The recorded data that triggered it.
  final String evidence;

  /// Higher first.
  final int priority;
}

/// Rule-based recommendation engine (baseline for Module 6).
///
/// No language model is involved: there is no AI backend or API key in this
/// project, and shipping a key inside the Flutter app would expose it. Each
/// rule fires only on the user's own recorded data and states that evidence.
class RecommendationService {
  const RecommendationService();

  static const String sourceLabel = 'Rule-based suggestions from your data';
  static const int distractingAppThresholdMinutes = 30;

  List<Recommendation> generate({
    required HistoryData history,

    /// Module 3 analysis of the last 7 days.
    required BehaviorAnalysis analysis,
    int limit = 4,
  }) {
    final List<Recommendation> out = <Recommendation>[];
    final DailyActivityLog? today = history.todayActivity;
    final List<AppUsageEntry> todayApps =
        history.appUsageByDay[history.todayKey] ?? const <AppUsageEntry>[];
    final double? limitHours = ProductivityScoreService.parseHours(
      history.goals?.targetScreenTimeLimit,
    );

    // 1. Over the screen-time limit today.
    final int? usage = today?.appUsageMinutes;
    if (usage != null && limitHours != null && usage > limitHours * 60) {
      final int over = usage - (limitHours * 60).round();
      out.add(
        Recommendation(
          id: 'over_limit_today',
          title: 'You are over your screen-time limit',
          action: 'Put the phone out of reach for your next study block.',
          evidence:
              'App use today: ${formatMinutes(usage)} vs your ${formatMinutes((limitHours * 60).round())} '
              'limit (${formatMinutes(over)} over).',
          priority: 100,
        ),
      );
    }

    // 2. Heaviest distracting app today.
    final List<AppUsageEntry> distracting =
        todayApps.where((a) => a.category == AppCategory.distracting).toList()
          ..sort(
            (a, b) => b.foregroundDuration.compareTo(a.foregroundDuration),
          );
    if (distracting.isNotEmpty &&
        distracting.first.usageMinutes >= distractingAppThresholdMinutes) {
      final AppUsageEntry app = distracting.first;
      out.add(
        Recommendation(
          id: 'distracting_app_today_${app.packageName}',
          title: 'Limit ${app.displayName}',
          action:
              'Set an Android app timer (Digital Wellbeing) for ${app.displayName}, '
              'e.g. ${(app.usageMinutes * 0.7).round()} minutes tomorrow.',
          evidence:
              '${app.displayName} was used for ${app.durationLabel} today.',
          priority: 90,
        ),
      );
    }

    // 3. Habitual distracting apps detected by Module 3 (user categories
    //    already applied by the engine).
    for (final DetectedHabit habit in analysis.habitsWithPrefix(
      'frequent_distracting_app:',
    )) {
      final String pkg = habit.packageName!;
      if (distracting.any((a) => a.packageName == pkg)) continue;
      final String name = habit.title.split(': ').last;
      out.add(
        Recommendation(
          id: 'habit_$pkg',
          title: habit.title.startsWith('Daily habit')
              ? 'Break the daily $name habit'
              : 'Watch your $name use',
          action: 'Move $name off your home screen to add friction.',
          evidence: habit.description,
          priority: 80,
        ),
      );
    }

    // 4. Rising measured usage trend.
    final DetectedHabit? trend = analysis.habit(
      'measured_app_usage_increasing',
    );
    if (trend != null) {
      out.add(
        Recommendation(
          id: 'usage_trend_up',
          title: 'Your phone use is climbing',
          action:
              'Pick one evening this week to keep the phone in another room.',
          evidence: trend.description,
          priority: 70,
        ),
      );
    }

    // 5. Weakest component of today's (or the recent) score.
    final SavedDailyScore? todayScore = history.todayScore;
    if (todayScore != null) {
      String? weakestKey;
      double weakest = 101;
      todayScore.componentScores.forEach((String key, double? value) {
        if (value != null && value < weakest) {
          weakest = value;
          weakestKey = key;
        }
      });
      if (weakestKey != null && weakest < 70) {
        out.add(_componentRecommendation(weakestKey!, weakest, history));
      }
    } else {
      out.add(
        const Recommendation(
          id: 'log_today',
          title: 'Log today to get your score',
          action: 'Open "Log Today\'s Progress" and record sleep and focus.',
          evidence: 'No productivity log has been saved for today yet.',
          priority: 40,
        ),
      );
    }

    // 6. No focus sessions recently while a focus goal exists.
    final bool hasFocusGoal =
        ProductivityScoreService.parseHours(history.goals?.targetFocusHours) !=
        null;
    final DateTime threeDaysAgo = ActivityDateUtils.lastDays(
      history.today,
      3,
    ).first;
    final bool recentFocus = history.focusSessions.any(
      (s) => !s.startedAt.isBefore(threeDaysAgo),
    );
    if (hasFocusGoal && !recentFocus) {
      out.add(
        const Recommendation(
          id: 'no_recent_focus',
          title: 'Start a focus session',
          action: 'Run one 25-minute Focus Mode session today.',
          evidence: 'No focus sessions recorded in the last 3 days.',
          priority: 50,
        ),
      );
    }

    // 7. Little movement today (only when movement is actually measured).
    if (today != null && today.hasMovementData) {
      final int active = today.activeMinutes ?? 0;

      if (active < 15 && history.today.hour >= 15) {
        out.add(
          Recommendation(
            id: 'low_movement',
            title: 'Get moving',
            action: 'Take a 15-minute walk between study blocks.',
            evidence: 'Only $active active minutes detected today.',
            priority: 45,
          ),
        );
      }
    }

    final Set<String> seen = <String>{};
    final List<Recommendation> unique =
        out.where((r) => seen.add(r.id)).toList()
          ..sort((a, b) => b.priority.compareTo(a.priority));
    return unique.take(limit).toList();
  }

  Recommendation _componentRecommendation(
    String key,
    double score,
    HistoryData history,
  ) {
    final String evidence =
        'Today\'s ${_label(key)} score was ${score.round()}/100.';
    switch (key) {
      case 'focus':
        return Recommendation(
          id: 'component_focus',
          title: 'Protect time for deep focus',
          action:
              'Block a 50-minute slot with Focus Mode before opening social apps.',
          evidence: evidence,
          priority: 60,
        );
      case 'sleep':
        return Recommendation(
          id: 'component_sleep',
          title: 'Prioritise sleep tonight',
          action:
              'Stop using your phone 30 minutes before your planned bedtime.',
          evidence: evidence,
          priority: 60,
        );
      case 'lowDistraction':
        return Recommendation(
          id: 'component_distraction',
          title: 'Reduce screen time',
          action: 'Turn on Focus/Do Not Disturb during study hours.',
          evidence: evidence,
          priority: 60,
        );
      case 'activity':
        return Recommendation(
          id: 'component_activity',
          title: 'Add some movement',
          action: 'Walk for 15 minutes after your next study session.',
          evidence: evidence,
          priority: 60,
        );
      default:
        return Recommendation(
          id: 'component_consistency',
          title: 'Keep a fixed routine',
          action: 'Plan tomorrow\'s study slot tonight and stick to it.',
          evidence: evidence,
          priority: 60,
        );
    }
  }

  static String _label(String key) {
    switch (key) {
      case 'lowDistraction':
        return 'low-distraction';
      case 'activity':
        return 'physical-activity';
    }
    return key;
  }
}
