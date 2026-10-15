import 'package:flutter_test/flutter_test.dart';
import 'package:vivora/features/activity_monitoring/data/models/activity_date_utils.dart';
import 'package:vivora/features/activity_monitoring/data/models/app_usage_entry.dart';
import 'package:vivora/features/activity_monitoring/data/models/daily_activity_log.dart';
import 'package:vivora/features/analytics/data/analytics_calculator.dart';
import 'package:vivora/features/badges/data/badge_service.dart';
import 'package:vivora/features/first_time_setup/data/models/user_profile_model.dart';
import 'package:vivora/features/focus_mode/data/focus_session_repository.dart';
import 'package:vivora/features/insights/data/history_data.dart';
import 'package:vivora/features/behavior_analysis/domain/behavior_analysis_engine.dart';
import 'package:vivora/features/behavior_analysis/domain/behavior_models.dart';
import 'package:vivora/features/insights/services/recommendation_service.dart';
import 'package:vivora/features/productivity_scoring/data/models/productivity_models.dart';

import 'support/fakes.dart';

final DateTime today = DateTime(2026, 10, 14, 16, 0);

DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

SavedDailyScore score(int daysBack, double? value, {double? sleep}) =>
    SavedDailyScore(
      log: DailyProductivityLog(
        date: daysAgo(daysBack),
        actualSleepHours: sleep,
      ),
      overallScore: value,
      performanceLevel: null,
      feedbackMessage: null,
      suggestions: const <String>[],
      coverage: 1,
      missingComponents: const <String>[],
      componentScores: <String, double?>{'focus': value, 'sleep': value},
    );

DailyActivityLog activity(
  int daysBack,
  int minutes, {
  int distracting = 0,
  int productive = 0,
}) => DailyActivityLog(
  date: daysAgo(daysBack),
  appUsageMinutes: minutes,
  distractingAppMinutes: distracting,
  productiveAppMinutes: productive,
  phoneUnlockCount: 30,
);

HistoryData history({
  List<DailyActivityLog> logs = const <DailyActivityLog>[],
  Map<String, List<AppUsageEntry>> apps = const <String, List<AppUsageEntry>>{},
  List<SavedDailyScore> scores = const <SavedDailyScore>[],
  List<FocusSession> focus = const <FocusSession>[],
  UserGoals? goals,
}) => HistoryData(
  today: today,
  activityLogs: logs,
  appUsageByDay: apps,
  scores: scores,
  focusSessions: focus,
  goals: goals,
);

void main() {
  group('AnalyticsCalculator', () {
    test('weekly points use only saved days, oldest first', () {
      final points = AnalyticsCalculator.scorePoints(<SavedDailyScore>[
        score(0, 80),
        score(3, 60),
        score(10, 99),
      ], today);
      expect(points.map((p) => p.value), <double>[60, 80]);
      expect(points.last.label, 'Wed'); // 2026-10-14 is a Wednesday
    });

    test('zero and one data point are handled', () {
      expect(
        AnalyticsCalculator.scorePoints(const <SavedDailyScore>[], today),
        isEmpty,
      );
      expect(
        AnalyticsCalculator.scorePoints(<SavedDailyScore>[score(0, 50)], today),
        hasLength(1),
      );
    });

    test('top day needs two days, and ties go to the most recent', () {
      expect(
        AnalyticsCalculator.topDay(<SavedDailyScore>[score(0, 90)]),
        isNull,
      );
      final tie = AnalyticsCalculator.topDay(<SavedDailyScore>[
        score(3, 70),
        score(1, 70),
        score(2, 50),
      ]);
      expect(tie!.date, daysAgo(1));
      expect(tie.tied, isTrue);
      final clear = AnalyticsCalculator.topDay(<SavedDailyScore>[
        score(3, 88),
        score(1, 70),
      ]);
      expect(clear!.date, daysAgo(3));
      expect(clear.tied, isFalse);
    });

    test('streaks count consecutive calendar days', () {
      final scores = <SavedDailyScore>[
        score(6, 50),
        score(5, 50),
        score(4, 50),
        score(2, 50),
        score(1, 50),
      ];
      expect(AnalyticsCalculator.bestStreak(scores), 3);
      // Today not logged yet: the streak ending yesterday still counts.
      expect(AnalyticsCalculator.currentStreak(scores, today), 2);
      expect(
        AnalyticsCalculator.currentStreak(<SavedDailyScore>[
          score(3, 50),
        ], today),
        0,
      );
    });

    test('streaks cross a month boundary', () {
      final scores = <SavedDailyScore>[
        for (int i = 0; i < 20; i++) score(i, 60),
      ];
      expect(AnalyticsCalculator.bestStreak(scores), 20);
    });

    test('focus ratio only uses categorised app time', () {
      final ratio = AnalyticsCalculator.appFocusRatio(
        activity(0, 100, distracting: 30, productive: 10),
      );
      expect(ratio.map((p) => p.value), <double>[10, 30]);
      expect(
        AnalyticsCalculator.appFocusRatio(null).every((p) => p.value == 0),
        isTrue,
      );
    });

    test('period summary averages only recorded days', () {
      final summary = PeriodSummary.of(
        scores: <SavedDailyScore>[
          score(0, 80, sleep: 8),
          score(2, 60, sleep: 6),
          score(20, 10),
        ],
        activity: <DailyActivityLog>[activity(1, 100), activity(2, 50)],
        today: today,
        days: 7,
      );
      expect(summary.loggedDays, 2);
      expect(summary.averageScore, 70);
      expect(summary.averageSleepHours, 7);
      expect(summary.averageAppUsageMinutes, 75);
      expect(summary.topDay!.date, daysAgo(0));
    });
  });

  group('RecommendationService', () {
    const engine = RecommendationService();
    const analysis = BehaviorAnalysisEngine();

    test('every recommendation cites recorded evidence', () {
      final h = history(
        logs: <DailyActivityLog>[activity(0, 250)],
        apps: <String, List<AppUsageEntry>>{
          ActivityDateUtils.dayKey(today): <AppUsageEntry>[
            app(
              'com.google.android.youtube',
              'YouTube',
              const Duration(minutes: 47),
              category: AppCategory.distracting,
            ),
          ],
        },
        goals: UserGoals(targetScreenTimeLimit: '3h', targetFocusHours: '2h'),
      );
      final recs = engine.generate(
        history: h,
        analysis: analysis.analyze(h, AnalysisPeriod.week),
      );
      final ids = recs.map((r) => r.id).toList();
      expect(ids.first, 'over_limit_today');
      expect(ids, contains('distracting_app_today_com.google.android.youtube'));
      expect(
        recs.firstWhere((r) => r.id.startsWith('distracting')).evidence,
        contains('47m'),
      );
      expect(recs.every((r) => r.evidence.isNotEmpty), isTrue);
    });

    test('with no data it only asks for a log, inventing nothing', () {
      final h = history();
      final recs = engine.generate(
        history: h,
        analysis: analysis.analyze(h, AnalysisPeriod.week),
      );
      expect(recs.map((r) => r.id), <String>['log_today']);
    });
  });

  group('BadgeService', () {
    test('badges come only from records', () {
      expect(BadgeService.evaluate(history()), isEmpty);

      final earned = BadgeService.evaluate(
        history(
          scores: <SavedDailyScore>[
            score(2, 60, sleep: 8),
            score(1, 90, sleep: 8),
            score(0, 70, sleep: 8),
          ],
          logs: <DailyActivityLog>[activity(1, 120)],
          focus: <FocusSession>[
            FocusSession(
              startedAt: daysAgo(1),
              endedAt: daysAgo(1),
              plannedMinutes: 25,
              focusedSeconds: 1500,
              completed: true,
            ),
          ],
          goals: UserGoals(targetSleepHours: '8h', targetScreenTimeLimit: '3h'),
        ),
      );
      expect(
        earned,
        containsAll(<String>[
          'first_log',
          'streak_3',
          'focus_first',
          'well_rested',
          'digital_detox',
          'productivity_pro',
        ]),
      );
      expect(earned, isNot(contains('streak_7')));
      expect(earned, isNot(contains('focus_king')));
    });
  });
}
