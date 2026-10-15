import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivora/features/analytics/presentation/analytics_screen.dart';
import 'package:vivora/features/activity_monitoring/data/models/app_usage_entry.dart';
import 'package:vivora/features/behavior_analysis/domain/behavior_analysis_engine.dart';
import 'package:vivora/features/behavior_analysis/domain/behavior_models.dart';
import 'package:vivora/features/behavior_analysis/presentation/behavior_insights_section.dart';
import 'package:vivora/features/insights/data/history_data.dart';
import 'package:vivora/features/insights/services/insights_service.dart';
import 'package:vivora/features/productivity_scoring/data/models/productivity_models.dart';

import 'support/behavior_builders.dart';
import 'support/layout_harness.dart';

/// In-memory stand-in for Firestore, keyed by user id.
class FakeInsightsSource implements InsightsSource {
  final Map<String, List<SavedDailyScore>> logsByUser =
      <String, List<SavedDailyScore>>{};
  final Set<String> failingParts = <String>{};
  int loads = 0;
  int stores = 0;
  Completer<void>? gate;

  @override
  Future<HistoryData> load(
    String uid,
    DateTime now, {
    required int days,
    required void Function(String what) onPartialFailure,
  }) async {
    loads++;
    if (gate != null) await gate!.future;
    failingParts.forEach(onPartialFailure);
    return bHistory(
      logs: failingParts.contains('scores')
          ? const <SavedDailyScore>[]
          : List<SavedDailyScore>.of(
              logsByUser[uid] ?? const <SavedDailyScore>[],
            ),
      goals: bGoals,
      now: now,
    );
  }

  @override
  Future<void> store(
    String uid,
    DateTime now,
    Map<AnalysisPeriod, BehaviorAnalysis> analyses,
  ) async => stores++;
}

void main() {
  late FakeInsightsSource source;
  late String? uid;
  late StreamController<String?> users;
  late ValueNotifier<int> revision;

  InsightsService build() => InsightsService(
    source: source,
    currentUserId: () => uid,
    userChanges: users.stream,
    invalidators: <Listenable>[revision],
    clock: () => bNow,
  );

  setUp(() {
    source = FakeInsightsSource();
    uid = 'alice';
    users = StreamController<String?>.broadcast();
    revision = ValueNotifier<int>(0);
    source.logsByUser['alice'] = <SavedDailyScore>[
      for (int d = 1; d <= 6; d++) bLog(d, study: 3.5, sleep: 7.5, score: 80),
    ];
    source.logsByUser['bob'] = <SavedDailyScore>[
      bLog(1, study: 0.5, score: 40),
    ];
  });

  tearDown(() => users.close());

  test(
    'repository data reaches the engine and is cached (Scenario C)',
    () async {
      final InsightsService service = build();
      final InsightsSnapshot? s = await service.ensureLoaded();
      final BehaviorAnalysis week = service.analysisFor(AnalysisPeriod.week)!;
      expect(s, isNotNull);
      expect(week.habit('study_goal_met'), isNotNull);
      expect(source.stores, 1);
      await service.ensureLoaded();
      expect(source.loads, 1, reason: 'unchanged data is not re-read');
    },
  );

  test('Scenario G: a changed daily log recalculates the insights', () async {
    final InsightsService service = build();
    await service.ensureLoaded();
    expect(
      service.analysisFor(AnalysisPeriod.week)!.habit('study_goal_met'),
      isNotNull,
    );

    source.logsByUser['alice'] = <SavedDailyScore>[
      for (int d = 1; d <= 6; d++) bLog(d, study: 0.5, score: 50),
    ];
    revision.value++; // what ProductivityRepository does after a save
    await Future<void>.delayed(Duration.zero);
    await service.reload();
    final BehaviorAnalysis week = service.analysisFor(AnalysisPeriod.week)!;
    expect(week.habit('study_goal_met'), isNull);
    expect(week.habit('study_goal_missed'), isNotNull);
  });

  test(
    'Scenario H: a restart (new service, same data) gives identical results',
    () async {
      final InsightsService first = build();
      await first.ensureLoaded();
      final InsightsService second = build();
      await second.ensureLoaded();
      expect(
        second.analysisFor(AnalysisPeriod.month)!.toMap().toString(),
        first.analysisFor(AnalysisPeriod.month)!.toMap().toString(),
      );
    },
  );

  test(
    'Scenario I: offline / partial load keeps what is available and says so',
    () async {
      source.failingParts.add('scores');
      final InsightsService service = build();
      final InsightsSnapshot? s = await service.ensureLoaded();
      expect(s!.loadError, contains('scores'));
      expect(
        service.analysisFor(AnalysisPeriod.week)!.dataQuality.missing.keys,
        contains('daily_logs'),
      );
    },
  );

  test(
    'Scenario J: switching account never shows the previous user\'s data',
    () async {
      final InsightsService service = build();
      await service.ensureLoaded();
      expect(
        service.analysisFor(AnalysisPeriod.week)!.dataQuality.loggedDays,
        6,
      );

      uid = 'bob';
      users.add('bob');
      await Future<void>.delayed(Duration.zero);
      expect(
        service.snapshot.value,
        isNull,
        reason: 'cleared immediately on sign-in change',
      );

      await service.ensureLoaded();
      expect(
        service.analysisFor(AnalysisPeriod.week)!.dataQuality.loggedDays,
        1,
      );
    },
  );

  test('a load still in flight for the previous user is discarded', () async {
    final InsightsService service = build();
    source.gate = Completer<void>();
    final Future<InsightsSnapshot?> pending = service.ensureLoaded();
    uid = 'bob';
    users.add('bob');
    source.gate!.complete();
    expect(await pending, isNull);
    expect(service.snapshot.value, isNull);
  });

  testWidgets('Analytics shows the calculated habits', (tester) async {
    final InsightsService service = build();
    await service.ensureLoaded();
    await tester.pumpWidget(
      MaterialApp(
        home: AnalyticsView(
          snapshot: service.snapshot.value,
          today: null,
          now: bNow,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.scrollUntilVisible(
      find.text('Repeatedly meeting your study goal'),
      400,
    );
    expect(find.text('Repeatedly meeting your study goal'), findsOneWidget);
    expect(
      find.textContaining('5 of 6'),
      findsNothing,
      reason: 'all 6 days met the goal',
    );
    expect(find.textContaining('6 of 6 logged days'), findsWidgets);
  });

  group('Patterns & Habits section is responsive', () {
    Map<AnalysisPeriod, BehaviorAnalysis> analyses(HistoryData h) =>
        const BehaviorAnalysisEngineProvider().all(h);

    testWidgets(
      'loading',
      (t) => expectResponsive(
        t,
        () => const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: BehaviorInsightsSection(analyses: null),
          ),
        ),
        heights: const <double>[640],
      ),
    );
    testWidgets(
      'no data',
      (t) => expectResponsive(
        t,
        () => Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: BehaviorInsightsSection(analyses: analyses(bHistory())),
          ),
        ),
        heights: const <double>[5000],
      ),
    );
    for (final AnalysisPeriod period in AnalysisPeriod.values) {
      testWidgets(
        'rich data, ${period.label}',
        (t) => expectResponsive(
          t,
          () => Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: BehaviorInsightsSection(
                analyses: analyses(richHistory()),
                initialPeriod: period,
              ),
            ),
          ),
          heights: const <double>[5000],
          interact: (tester) async {
            await tester.tap(find.text('What this analysis cannot tell'));
            await tester.pump(const Duration(milliseconds: 400));
          },
        ),
      );
    }
  });
}

HistoryData richHistory() => bHistory(
  logs: <SavedDailyScore>[
    for (int d = 0; d < 30; d++)
      bLog(
        d,
        sleep: d.isEven ? 6 : 8.5,
        study: 1.0 + d % 4,
        focus: d < 8 ? 1 : 3,
        routine: 30.0 + d,
        activity: 50,
        score: 50.0 + (d % 7) * 6,
      ),
  ],
  activity: [
    for (int d = 0; d < 30; d++)
      bActivity(
        d,
        app: 150 + d * 4,
        unlocks: 1234,
        apps: [
          bApp(
            'com.google.android.youtube',
            'YouTube',
            60.0 + d,
            AppCategory.distracting,
          ),
          bApp(
            'com.example.longname',
            'Microsoft Office Mobile Productivity Suite for Students',
            40,
            AppCategory.productive,
          ),
        ],
      ),
  ],
  sessions: [for (int d = 0; d < 10; d++) bSession(d, 21, 50)],
  goals: bGoals,
);

/// Small helper so tests do not depend on the service for pure analysis.
class BehaviorAnalysisEngineProvider {
  const BehaviorAnalysisEngineProvider();
  Map<AnalysisPeriod, BehaviorAnalysis> all(HistoryData h) =>
      const BehaviorAnalysisEngine().analyzeAll(h, calculatedAt: bNow);
}
