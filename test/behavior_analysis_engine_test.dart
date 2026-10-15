import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vivora/features/activity_monitoring/data/models/app_usage_entry.dart';
import 'package:vivora/features/behavior_analysis/domain/behavior_analysis_engine.dart';
import 'package:vivora/features/behavior_analysis/domain/behavior_models.dart';
import 'package:vivora/features/behavior_analysis/domain/behavior_stats.dart';
import 'package:vivora/features/behavior_analysis/domain/behavior_thresholds.dart';
import 'package:vivora/features/behavior_analysis/domain/history_normalizer.dart';
import 'package:vivora/features/focus_mode/data/focus_session_repository.dart';

import 'support/behavior_builders.dart';

const BehaviorAnalysisEngine engine = BehaviorAnalysisEngine();

BehaviorAnalysis week(history) => engine.analyze(history, AnalysisPeriod.week);
BehaviorAnalysis month(history) =>
    engine.analyze(history, AnalysisPeriod.month);
BehaviorAnalysis today(history) => engine.analyze(history, AnalysisPeriod.day);

Set<String> ids(BehaviorAnalysis a) => a.habits.map((h) => h.id).toSet();

void main() {
  group('BehaviorStats', () {
    test('mean and standard deviation ignore nothing and invent nothing', () {
      expect(BehaviorStats.mean(<double>[]), isNull);
      expect(BehaviorStats.mean(<double>[2, 4]), 3);
      expect(BehaviorStats.standardDeviation(<double>[5]), isNull);
      expect(
        BehaviorStats.standardDeviation(<double>[2, 4, 4, 4, 5, 5, 7, 9]),
        2,
      );
    });

    test('Pearson needs enough pairs and variation', () {
      expect(
        BehaviorStats.pearson(<double>[1, 2], <double>[2, 4], minPairs: 7),
        isNull,
      );
      final List<double> xs = <double>[1, 2, 3, 4, 5, 6, 7];
      expect(
        BehaviorStats.pearson(
          xs,
          xs.map((x) => 2 * x + 1).toList(),
          minPairs: 7,
        ),
        closeTo(1, 1e-9),
      );
      expect(
        BehaviorStats.pearson(xs, xs.map((x) => -x).toList(), minPairs: 7),
        closeTo(-1, 1e-9),
      );
      expect(
        BehaviorStats.pearson(xs, List<double>.filled(7, 5), minPairs: 7),
        isNull,
        reason: 'all values equal',
      );
    });

    test('trend direction: insufficient, stable, increasing, decreasing', () {
      const t = BehaviorThresholds();
      TrendDirection d(List<double> cur, List<double> prev, double floor) =>
          BehaviorStats.trend(
            metric: 'm',
            unit: 'minutes',
            source: DataSource.measured,
            current: cur,
            previous: prev,
            basis: 'b',
            absoluteFloor: floor,
            thresholds: t,
          ).direction;
      expect(
        d(<double>[100, 100], <double>[50, 50, 50], 10),
        TrendDirection.insufficientData,
      );
      expect(
        d(<double>[105, 105, 105], <double>[100, 100, 100], 10),
        TrendDirection.stable,
      );
      expect(
        d(<double>[130, 130, 130], <double>[100, 100, 100], 10),
        TrendDirection.increasing,
      );
      expect(
        d(<double>[70, 70, 70], <double>[100, 100, 100], 10),
        TrendDirection.decreasing,
      );
      // 2 → 3 minutes is +50% but below the absolute floor: not a trend.
      expect(
        d(<double>[3, 3, 3], <double>[2, 2, 2], 10),
        TrendDirection.stable,
      );
    });

    test('streaks use calendar dates and count each day once', () {
      final List<String> keys = <String>[
        '2026-10-10',
        '2026-10-11',
        '2026-10-11',
        '2026-10-13',
        '2026-10-14',
      ];
      expect(BehaviorStats.bestStreak(keys), 2);
      expect(
        BehaviorStats.currentStreak(keys, DateTime(2026, 10, 15, 9)),
        2,
        reason: 'today not logged yet',
      );
      expect(
        BehaviorStats.bestStreak(<String>[
          '2026-09-30',
          '2026-10-01',
          '2026-10-02',
        ]),
        3,
        reason: 'month boundary',
      );
    });
  });

  group('data quality', () {
    test(
      'future dates, duplicates and impossible values are excluded and counted',
      () {
        final n = const HistoryNormalizer().normalize(
          bHistory(
            logs: <dynamic>[
              bLog(0, sleep: 7),
              bLog(0, sleep: 3), // duplicate day
              bLog(-1, sleep: 8), // future
              bLog(
                1,
                sleep: -2,
                study: 30,
                routine: 140,
                score: 70,
              ), // invalid values
            ].cast(),
            activity: <dynamic>[
              bActivity(2, app: 1500, unlocked: 200), // > 24 h
              bActivity(3, app: 600, unlocked: 100), // conflicting sources
            ].cast(),
          ),
        );
        expect(n.excluded['future_date'], 1);
        expect(n.excluded['duplicate_day'], 1);
        expect(n.excluded['invalid_value'], 4);
        expect(n.excluded['conflicting_sources'], 1);
        expect(n.warnings.single, contains('exceeds unlocked screen time'));
        expect(
          n.day('2026-10-15')!.sleepHours,
          7,
          reason: 'first record for the day kept',
        );
        final yesterday = n.day('2026-10-14')!;
        expect(yesterday.sleepHours, isNull);
        expect(yesterday.studyHours, isNull);
        expect(
          yesterday.score,
          70,
          reason: 'valid fields of a partly invalid record are kept',
        );
        expect(n.day('2026-10-12')!.hasMeasurement, isFalse);
      },
    );

    test('duplicate activity records keep the latest sync', () {
      final n = const HistoryNormalizer().normalize(
        bHistory(
          activity: <dynamic>[
            bActivity(1, app: 50, syncedAt: bDay(1, 10)),
            bActivity(1, app: 90, syncedAt: bDay(1, 22)),
          ].cast(),
        ),
      );
      expect(n.day('2026-10-14')!.appUsageMinutes, 90);
    });

    test(
      'focus sessions: invalid, duplicate and overlapping time are not counted',
      () {
        final DateTime s = bDay(1, 10);
        final n = const HistoryNormalizer().normalize(
          bHistory(
            sessions: <FocusSession>[
              bSession(1, 10, 25, id: 'a'),
              bSession(1, 10, 25, id: 'a'), // duplicate
              FocusSession(
                startedAt: s.add(const Duration(minutes: 15)),
                endedAt: s.add(const Duration(minutes: 40)),
                plannedMinutes: 25,
                focusedSeconds: 1500,
                completed: true,
                id: 'b',
              ), // overlaps 10 min
              FocusSession(
                startedAt: s,
                endedAt: s.subtract(const Duration(minutes: 5)),
                plannedMinutes: 25,
                focusedSeconds: 60,
                completed: false,
                id: 'c',
              ), // ends before start
            ],
          ),
        );
        expect(n.excluded['duplicate_session'], 1);
        expect(n.excluded['invalid_session'], 1);
        expect(
          n.day('2026-10-14')!.focusSessionMinutes,
          40,
          reason: '25 + (25 − 10 overlap)',
        );
      },
    );

    test('local day boundaries: 23:59 and 00:00 belong to different days', () {
      final n = const HistoryNormalizer().normalize(
        bHistory(
          sessions: <FocusSession>[
            bSession(2, 23, 1),
            FocusSession(
              startedAt: bDay(1),
              endedAt: bDay(1).add(const Duration(minutes: 1)),
              plannedMinutes: 1,
              focusedSeconds: 60,
              completed: true,
            ),
          ],
        ),
      );
      expect(n.day('2026-10-13')!.focusSessions, 1);
      expect(n.day('2026-10-14')!.focusSessions, 1);
    });

    test('Scenario F: missing days are not zero', () {
      final a = week(
        bHistory(
          logs: <dynamic>[
            bLog(1, sleep: 8),
            bLog(3, sleep: 6),
            bLog(5, sleep: 7),
          ].cast(),
        ),
      );
      final MetricStats sleep = a.metrics['sleepHours']!;
      expect(sleep.count, 3);
      expect(sleep.missingDays, 4);
      expect(
        sleep.mean,
        7,
        reason: 'averaged over 3 logged nights, not 7 days',
      );
      expect(a.dataQuality.loggedDays, 3);
    });

    test(
      'today\'s measurement is partial: excluded from 7-day comparisons, shown for today',
      () {
        final h = bHistory(
          activity: <dynamic>[
            bActivity(0, app: 500),
            bActivity(1, app: 100),
            bActivity(2, app: 100),
          ].cast(),
        );
        expect(week(h).metrics['appUsageMinutes']!.mean, 100);
        expect(today(h).metrics['appUsageMinutes']!.mean, 500);
      },
    );

    test('very large but valid durations are accepted', () {
      final a = week(
        bHistory(
          activity: <dynamic>[bActivity(1, app: 1400, unlocked: 1440)].cast(),
        ),
      );
      expect(a.metrics['appUsageMinutes']!.max!.value, 1400);
    });
  });

  group('Scenario A/B: no data and a single day', () {
    test(
      'A: a new user gets no insights and an explanation of what is missing',
      () {
        final a = week(bHistory());
        expect(a.hasAnyData, isFalse);
        expect(a.habits, isEmpty);
        expect(
          a.dataQuality.missing.keys,
          containsAll(<String>['daily_logs', 'measured_usage', 'goals']),
        );
      },
    );

    test('B: one day yields single-day observations only', () {
      final h = bHistory(
        logs: <dynamic>[bLog(0, sleep: 6, study: 4, score: 72)].cast(),
        activity: <dynamic>[
          bActivity(
            0,
            app: 95,
            apps: <AppUsageEntry>[
              bApp(
                'com.google.android.youtube',
                'YouTube',
                60,
                AppCategory.distracting,
              ),
            ],
          ),
        ].cast(),
        sessions: <FocusSession>[bSession(0, 9, 25)],
        goals: bGoals,
      );
      final d = today(h);
      expect(d.habits, isNotEmpty);
      expect(d.habits.every((x) => x.isSingleDayObservation), isTrue);
      expect(
        ids(d),
        containsAll(<String>[
          'today_score',
          'today_goal_sleep',
          'today_goal_study',
          'today_focus_sessions',
          'today_top_app',
        ]),
      );
      // The 7-day view must not turn one day into a habit.
      final w = week(h);
      expect(w.habits.where((x) => !x.isSingleDayObservation), isEmpty);
    });

    test('two days are not enough for a pattern', () {
      final w = week(
        bHistory(
          logs: <dynamic>[bLog(1, study: 4), bLog(2, study: 4)].cast(),
          goals: bGoals,
        ),
      );
      expect(w.habits, isEmpty);
    });
  });

  group('screen time and app usage', () {
    test('averages, highest/lowest day and ranking use measured data', () {
      final h = bHistory(
        activity: <dynamic>[
          bActivity(
            1,
            app: 120,
            unlocked: 150,
            unlocks: 40,
            apps: <AppUsageEntry>[
              bApp('yt', 'YouTube', 80, AppCategory.distracting),
              bApp('wa', 'WhatsApp', 40, AppCategory.neutral),
            ],
          ),
          bActivity(
            2,
            app: 60,
            unlocked: 80,
            unlocks: 20,
            apps: <AppUsageEntry>[
              bApp('yt', 'YouTube', 10, AppCategory.distracting),
              bApp('docs', 'Docs', 50, AppCategory.productive),
            ],
          ),
        ].cast(),
      );
      final a = week(h);
      expect(a.metrics['appUsageMinutes']!.mean, 90);
      expect(a.metrics['appUsageMinutes']!.max!.dayKey, '2026-10-14');
      expect(a.metrics['appUsageMinutes']!.min!.dayKey, '2026-10-13');
      expect(
        a.metrics['screenUnlockedMinutes']!.mean,
        115,
        reason: 'kept separate from app usage',
      );
      expect(a.apps.map((x) => x.appName).toList(), <String>[
        'YouTube',
        'Docs',
        'WhatsApp',
      ]);
      expect(a.apps.first.totalMinutes, 90);
      expect(a.metrics['distractingAppMinutes']!.total, 90);
      expect(a.metrics['productiveAppMinutes']!.total, 50);
      expect(a.metrics['neutralAppMinutes']!.total, 40);
    });

    test('user-selected categories override the stored ones', () {
      final h = bHistory(
        activity: <dynamic>[
          bActivity(
            1,
            app: 60,
            apps: <AppUsageEntry>[
              bApp('yt', 'YouTube', 60, AppCategory.distracting),
            ],
          ),
        ].cast(),
        overrides: <String, AppCategory>{'yt': AppCategory.productive},
      );
      final a = week(h);
      expect(a.metrics['productiveAppMinutes']!.total, 60);
      expect(a.metrics['distractingAppMinutes']!.total, 0);
      expect(a.apps.single.categoryIsUserChoice, isTrue);
    });

    test('measured usage increase is reported with the real percentage', () {
      final h = bHistory(
        activity: <dynamic>[
          for (int d = 7; d <= 13; d++) bActivity(d, app: 100),
          for (int d = 1; d <= 6; d++) bActivity(d, app: 118),
        ].cast(),
      );
      final a = week(h);
      final TrendResult t = a.trends['appUsageMinutes']!;
      expect(t.direction, TrendDirection.increasing);
      expect(t.changeRatio, closeTo(0.18, 1e-9));
      expect(
        a.habit('measured_app_usage_increasing')!.description,
        contains('+18%'),
      );
      expect(
        a.habit('measured_app_usage_increasing')!.source,
        DataSource.measured,
      );
    });

    test(
      'Scenario D: increasing distraction is detected from measurements',
      () {
        List<AppUsageEntry> yt(double m) => <AppUsageEntry>[
          bApp('yt', 'YouTube', m, AppCategory.distracting),
        ];
        final h = bHistory(
          activity: <dynamic>[
            for (int d = 7; d <= 13; d++) bActivity(d, app: 100, apps: yt(30)),
            for (int d = 1; d <= 6; d++) bActivity(d, app: 160, apps: yt(90)),
          ].cast(),
        );
        final a = week(h);
        expect(ids(a), contains('distracting_usage_increasing'));
        expect(ids(a), contains('frequent_distracting_app:yt'));
        expect(
          a.habit('frequent_distracting_app:yt')!.title,
          'Daily habit: YouTube',
        );
        expect(
          a.habit('frequent_distracting_app:yt')!.polarity,
          InsightPolarity.negative,
        );
      },
    );

    test('no time-of-day claims from daily totals', () {
      final a = week(
        bHistory(
          activity: <dynamic>[
            for (int d = 1; d <= 7; d++) bActivity(d, app: 100),
          ].cast(),
        ),
      );
      expect(a.dataQuality.missing.keys, contains('app_time_of_day'));
      expect(
        a.habits.where(
          (x) => x.id.contains('time_of_day') && x.metric == 'appUsageMinutes',
        ),
        isEmpty,
      );
    });

    test('screen-time limit exceeded on most measured days', () {
      final a = week(
        bHistory(
          activity: <dynamic>[
            for (int d = 1; d <= 6; d++) bActivity(d, app: 240),
          ].cast(),
          goals: bGoals,
        ),
      );
      expect(ids(a), contains('appUsageLimit_goal_missed'));
      final GoalAchievement g = a.goals.firstWhere(
        (g) => g.goal == 'appUsageLimit',
      );
      expect(g.metDays, 0);
      expect(g.observedDays, 6);
    });
  });

  group('study, focus, sleep, routine, activity', () {
    test('Scenario C: consistent study days and met study goal', () {
      final a = week(
        bHistory(
          logs: <dynamic>[
            for (int d = 1; d <= 6; d++) bLog(d, study: d == 3 ? 2 : 3.5),
          ].cast(),
          goals: bGoals,
        ),
      );
      expect(
        ids(a),
        containsAll(<String>[
          'consistent_study',
          'study_goal_met',
          'regular_logging',
        ]),
      );
      expect(a.habit('study_goal_met')!.description, contains('5 of 6'));
      expect(a.habit('consistent_study')!.source, DataSource.selfReported);
      expect(
        a.habit('consistent_study')!.evidence,
        contains('Based on your own daily log entries.'),
      );
    });

    test(
      'focus sessions are tracked separately and give time-of-day patterns',
      () {
        final a = week(
          bHistory(
            sessions: <FocusSession>[
              for (int d = 1; d <= 5; d++) bSession(d, 19, 25),
            ],
          ),
        );
        expect(
          a.habit('focus_time_of_day')!.title,
          'You focus most in the evening',
        );
        expect(a.habit('focus_time_of_day')!.source, DataSource.tracked);
        expect(a.habit('regular_focus_sessions'), isNotNull);
        expect(
          a.metrics['deepFocusHours']!.count,
          0,
          reason: 'sessions are not self-reported focus',
        );
      },
    );

    test('logged deep focus decline is detected', () {
      final a = week(
        bHistory(
          logs: <dynamic>[
            for (int d = 8; d <= 12; d++) bLog(d, focus: 3),
            for (int d = 1; d <= 5; d++) bLog(d, focus: 1.5),
          ].cast(),
        ),
      );
      expect(ids(a), contains('focus_declining'));
    });

    test('consistent sleep and missed sleep goal', () {
      final a = week(
        bHistory(
          logs: <dynamic>[
            for (int d = 1; d <= 6; d++)
              bLog(d, sleep: 6 + (d.isEven ? 0.25 : 0)),
          ].cast(),
          goals: bGoals,
        ),
      );
      expect(
        ids(a),
        containsAll(<String>['consistent_sleep', 'sleep_goal_missed']),
      );
    });

    test('Scenario E: improving sleep consistency', () {
      final List<double> erratic = <double>[4, 9, 5, 9.5, 4.5, 8];
      final a = week(
        bHistory(
          logs: <dynamic>[
            for (int i = 0; i < 6; i++) bLog(8 + i, sleep: erratic[i]),
            for (int d = 1; d <= 6; d++) bLog(d, sleep: 7.5),
          ].cast(),
        ),
      );
      expect(ids(a), contains('sleep_consistency_improving'));
    });

    test('routine rating and logging regularity are different things', () {
      final a = week(
        bHistory(
          logs: <dynamic>[
            for (int d = 0; d <= 6; d++) bLog(d, routine: 30),
          ].cast(),
        ),
      );
      expect(ids(a), containsAll(<String>['regular_logging', 'weak_routine']));
      final strong = week(
        bHistory(
          logs: <dynamic>[
            for (int d = 1; d <= 5; d++) bLog(d, routine: 85),
          ].cast(),
        ),
      );
      expect(ids(strong), contains('strong_routine'));
    });

    test('irregular logging needs an earlier logging history', () {
      final a = week(
        bHistory(
          logs: <dynamic>[
            bLog(2, sleep: 7),
            bLog(12, sleep: 7),
            bLog(13, sleep: 7),
          ].cast(),
        ),
      );
      expect(ids(a), contains('irregular_logging'));
      final newUser = week(bHistory(logs: <dynamic>[bLog(2, sleep: 7)].cast()));
      expect(ids(newUser), isNot(contains('irregular_logging')));
    });

    test('self-rated activity is never presented as sensor data', () {
      final a = week(
        bHistory(
          logs: <dynamic>[
            for (int d = 1; d <= 4; d++) bLog(d, activity: 70),
          ].cast(),
        ),
      );
      expect(
        a.habit('activity_rating_summary')!.source,
        DataSource.selfReported,
      );
      expect(a.dataQuality.missing.keys, contains('movement_sensor'));
      expect(a.habit('measured_movement_summary'), isNull);
      final sensor = week(
        bHistory(
          activity: <dynamic>[
            for (int d = 1; d <= 3; d++) bActivity(d, app: 50, walking: 40),
          ].cast(),
        ),
      );
      expect(
        sensor.habit('measured_movement_summary')!.source,
        DataSource.measured,
      );
    });
  });

  group('productivity and relationships', () {
    test(
      'averages, extremes, levels and steadiness use existing thresholds',
      () {
        final a = week(
          bHistory(
            logs: <dynamic>[
              bLog(1, score: 80),
              bLog(2, score: 78),
              bLog(3, score: 82),
              bLog(4, score: 80),
              bLog(5, score: 79),
            ].cast(),
          ),
        );
        expect(a.metrics['score']!.mean, closeTo(79.8, 1e-9));
        expect(a.metrics['score']!.max!.value, 82);
        expect(
          a.habit('productive_day_share')!.title,
          '5 of 5 scored days were Good or Excellent',
        );
        expect(ids(a), contains('steady_productivity'));
      },
    );

    test('relationships need 7 paired days and are worded as associations', () {
      final few = week(
        bHistory(
          logs: <dynamic>[
            for (int d = 1; d <= 3; d++)
              bLog(d, sleep: 5.0 + d, score: 60.0 + d),
          ].cast(),
        ),
      );
      final r = few.relationships.firstWhere((r) => r.metric == 'sleepHours');
      expect(r.isConclusive, isFalse);
      expect(r.statement, contains('3 of 7 needed'));

      final many = month(
        bHistory(
          logs: <dynamic>[
            for (int d = 1; d <= 10; d++)
              bLog(d, sleep: 5.0 + d * 0.3, score: 50.0 + d * 3),
          ].cast(),
        ),
      );
      final sleep = many.relationships.firstWhere(
        (r) => r.metric == 'sleepHours',
      );
      expect(sleep.correlation, closeTo(1, 1e-9));
      expect(sleep.statement, contains('tended to be higher'));
      expect(sleep.statement, contains('part of the score calculation'));
      expect(sleep.statement.toLowerCase(), isNot(contains('caused')));
    });

    test('distracting time vs score (not part of the formula)', () {
      final a = month(
        bHistory(
          logs: <dynamic>[
            for (int d = 1; d <= 8; d++) bLog(d, score: 90.0 - d * 5),
          ].cast(),
          activity: <dynamic>[
            for (int d = 1; d <= 8; d++)
              bActivity(
                d,
                app: 200,
                apps: <AppUsageEntry>[
                  bApp('yt', 'YouTube', 20.0 * d, AppCategory.distracting),
                ],
              ),
          ].cast(),
        ),
      );
      final r = a.relationships.firstWhere(
        (r) => r.metric == 'distractingAppMinutes',
      );
      expect(r.correlation, closeTo(-1, 1e-9));
      expect(r.partOfScoreFormula, isFalse);
      expect(r.statement, contains('tended to be lower'));
    });

    test('day-of-week pattern needs enough weeks (30-day view)', () {
      final a = month(
        bHistory(
          logs: <dynamic>[
            for (int d = 0; d < 28; d++)
              bLog(d, score: bDay(d).weekday == DateTime.tuesday ? 90 : 60),
          ].cast(),
        ),
      );
      expect(
        a.habit('weekday_pattern:score')!.title,
        'Productivity score is higher on Tuesdays',
      );
      final short = month(
        bHistory(
          logs: <dynamic>[
            for (int d = 0; d < 5; d++) bLog(d, score: d == 2 ? 90 : 60),
          ].cast(),
        ),
      );
      expect(short.habit('weekday_pattern:score'), isNull);
    });

    test(
      '30 days of records: monthly analysis compares halves when no earlier month exists',
      () {
        final a = month(
          bHistory(
            activity: <dynamic>[
              for (int d = 1; d <= 29; d++)
                bActivity(d, app: d <= 15 ? 200 : 100),
            ].cast(),
          ),
        );
        expect(
          a.trends['appUsageMinutes']!.direction,
          TrendDirection.increasing,
        );
        expect(a.trends['appUsageMinutes']!.basis, contains('half'));
      },
    );
  });

  group('determinism and Module 6 output', () {
    test('same input gives identical, JSON-serialisable output', () {
      final h = bHistory(
        logs: <dynamic>[
          for (int d = 0; d < 20; d++)
            bLog(d, sleep: 7, study: 3, score: 70.0 + d % 5),
        ].cast(),
        activity: <dynamic>[
          for (int d = 0; d < 20; d++) bActivity(d, app: 100 + d),
        ].cast(),
        sessions: <FocusSession>[
          for (int d = 0; d < 6; d++) bSession(d, 9, 25),
        ],
        goals: bGoals,
      );
      final a = engine.analyzeAll(h, calculatedAt: bNow);
      final b = engine.analyzeAll(h, calculatedAt: bNow);
      for (final AnalysisPeriod p in AnalysisPeriod.values) {
        expect(jsonEncode(a[p]!.toMap()), jsonEncode(b[p]!.toMap()));
      }
      final Map<String, dynamic> decoded = jsonDecode(
        jsonEncode(a[AnalysisPeriod.week]!.toMap()),
      );
      expect(
        decoded.keys,
        containsAll(<String>[
          'habits',
          'trends',
          'goals',
          'apps',
          'relationships',
          'dataQuality',
          'metrics',
        ]),
      );
      expect(
        a[AnalysisPeriod.week]!.habits.first.priority >=
            a[AnalysisPeriod.week]!.habits.last.priority,
        isTrue,
      );
    });

    test('custom thresholds are honoured', () {
      final h = bHistory(
        logs: <dynamic>[for (int d = 1; d <= 3; d++) bLog(d, study: 4)].cast(),
        goals: bGoals,
      );
      expect(ids(week(h)), contains('study_goal_met'));
      const strict = BehaviorAnalysisEngine(
        thresholds: BehaviorThresholds(minSamplesForPattern: 5),
      );
      expect(
        strict.analyze(h, AnalysisPeriod.week).habit('study_goal_met'),
        isNull,
      );
    });
  });
}
