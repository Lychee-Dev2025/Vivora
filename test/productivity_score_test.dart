import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivora/features/first_time_setup/data/models/user_profile_model.dart';
import 'package:vivora/features/productivity_scoring/data/models/productivity_models.dart';
import 'package:vivora/features/productivity_scoring/data/services/productivity_score_service.dart';

void main() {
  final service = ProductivityScoreService();
  final goals = UserGoals(
    targetSleepHours: '8h',
    targetStudyHours: '4h',
    targetFocusHours: '4h',
    targetScreenTimeLimit: '3h',
  );
  final day = DateTime(2026, 10, 14, 21, 30);

  DailyProductivityLog log({
    double? sleep,
    double? focus,
    double? screen,
    double? consistency,
    double? activity,
    int? activeMinutes,
  }) => DailyProductivityLog(
    date: day,
    actualSleepHours: sleep,
    actualFocusHours: focus,
    actualScreenTimeHours: screen,
    consistencyScore: consistency,
    activityScore: activity,
    measuredActiveMinutes: activeMinutes,
  );

  test('weights are 30/20/20/15/15 and sum to 1', () {
    expect(
      ProductivityScoreService.focusWeight +
          ProductivityScoreService.sleepWeight +
          ProductivityScoreService.consistencyWeight +
          ProductivityScoreService.activityWeight +
          ProductivityScoreService.lowDistractionWeight,
      closeTo(1.0, 1e-9),
    );
    final r = service.calculate(
      log: log(sleep: 8, focus: 4, screen: 2, consistency: 100, activity: 100),
      goals: goals,
    );
    expect(r.componentScore('focus'), 100);
    expect(r.components.firstWhere((c) => c.key == 'focus').weight, 0.30);
    expect(r.components.firstWhere((c) => c.key == 'sleep').weight, 0.20);
    expect(r.components.firstWhere((c) => c.key == 'consistency').weight, 0.20);
    expect(r.components.firstWhere((c) => c.key == 'activity').weight, 0.15);
    expect(
      r.components.firstWhere((c) => c.key == 'lowDistraction').weight,
      0.15,
    );
  });

  test('full data: weighted sum is exact', () {
    // focus 2/4 = 50, sleep 6/8 = 75, consistency 60, activity 40,
    // screen 4h vs 3h limit -> 100 - 20 = 80.
    final r = service.calculate(
      log: log(sleep: 6, focus: 2, screen: 4, consistency: 60, activity: 40),
      goals: goals,
    );
    const expected = 0.30 * 50 + 0.20 * 75 + 0.20 * 60 + 0.15 * 40 + 0.15 * 80;
    expect(r.overallScore, closeTo(expected, 1e-9));
    expect(r.isPartial, isFalse);
    expect(r.performanceLevel, 'Medium');
  });

  test(
    'missing inputs are excluded and weights renormalised, never zero-filled',
    () {
      final r = service.calculate(log: log(focus: 4, sleep: 4), goals: goals);
      // focus 100 (w .30), sleep 50 (w .20) -> (30 + 10) / 0.5 = 80
      expect(r.overallScore, closeTo(80, 1e-9));
      expect(r.isPartial, isTrue);
      expect(r.coverage, closeTo(0.5, 1e-9));
      expect(
        r.missingComponents,
        containsAll(<String>[
          'Consistency',
          'Physical Activity',
          'Low Distraction',
        ]),
      );
    },
  );

  test('no inputs: no score at all', () {
    final r = service.calculate(log: log(), goals: goals);
    expect(r.overallScore, isNull);
    expect(r.performanceLevel, 'Not enough data');
  });

  test('a missing goal excludes the component instead of awarding 100', () {
    final r = service.calculate(
      log: log(focus: 0.5, sleep: 8),
      goals: UserGoals(targetSleepHours: '8h'),
    );
    expect(r.componentScore('focus'), isNull);
    expect(r.overallScore, 100); // only sleep (100) is scored
  });

  test('boundaries stay within 0..100', () {
    final low = service.calculate(
      log: log(sleep: 0, focus: 0, screen: 18, consistency: 0, activity: 0),
      goals: goals,
    );
    expect(low.overallScore, 0);
    final high = service.calculate(
      log: log(
        sleep: 12,
        focus: 12,
        screen: 0,
        consistency: 100,
        activity: 100,
      ),
      goals: goals,
    );
    expect(high.overallScore, 100);
    final overRated = service.calculate(
      log: log(consistency: 250),
      goals: goals,
    );
    expect(overRated.overallScore, 100);
  });

  test('screen time: 20 points per hour over the limit, floored at 0', () {
    expect(
      service
          .calculate(log: log(screen: 3), goals: goals)
          .componentScore('lowDistraction'),
      100,
    );
    expect(
      service
          .calculate(log: log(screen: 3.5), goals: goals)
          .componentScore('lowDistraction'),
      90,
    );
    expect(
      service
          .calculate(log: log(screen: 10), goals: goals)
          .componentScore('lowDistraction'),
      0,
    );
  });

  test('measured movement is used only when activity is not self-rated', () {
    expect(
      service
          .calculate(log: log(activeMinutes: 15), goals: goals)
          .componentScore('activity'),
      50,
    );
    expect(
      service
          .calculate(log: log(activeMinutes: 90), goals: goals)
          .componentScore('activity'),
      100,
    );
    expect(
      service
          .calculate(log: log(activity: 20, activeMinutes: 90), goals: goals)
          .componentScore('activity'),
      20,
    );
  });

  test('repeated calculations are deterministic', () {
    final input = log(
      sleep: 7.25,
      focus: 3,
      screen: 5,
      consistency: 55,
      activity: 65,
    );
    final a = service.calculate(log: input, goals: goals).overallScore;
    final b = service.calculate(log: input, goals: goals).overallScore;
    expect(a, b);
  });

  test('goal parsing handles decimals, "+" and junk', () {
    expect(ProductivityScoreService.parseHours('7.5h'), 7.5);
    expect(ProductivityScoreService.parseHours('5h+'), 5);
    expect(ProductivityScoreService.parseHours('8 hours'), 8);
    expect(ProductivityScoreService.parseHours(''), isNull);
    expect(ProductivityScoreService.parseHours('0h'), isNull);
    expect(ProductivityScoreService.parseHours(null), isNull);
  });

  group('persistence mapping', () {
    test(
      'a saved day round-trips with its date taken from the document id',
      () {
        final input = log(sleep: 7, focus: 2, screen: 4);
        final result = service.calculate(log: input, goals: goals);
        final map = <String, dynamic>{...input.toMap(), ...result.toMap()};
        // Simulate a timestamp stored under an older UTC convention.
        map['date'] = Timestamp.fromDate(DateTime.utc(2026, 10, 13, 19));

        final saved = SavedDailyScore.fromMap(map, documentId: '2026-10-14');
        expect(saved.date, DateTime(2026, 10, 14));
        expect(saved.overallScore, result.overallScore);
        expect(saved.log.actualSleepHours, 7);
        expect(
          saved.log.consistencyScore,
          isNull,
          reason: 'missing stays missing',
        );
        expect(saved.componentScores['lowDistraction'], 80);
        expect(saved.coverage, closeTo(0.65, 1e-9));
      },
    );

    test('legacy documents (all fields present, no coverage) still load', () {
      final saved = SavedDailyScore.fromMap(<String, dynamic>{
        'date': Timestamp.fromDate(DateTime(2026, 10, 10, 18)),
        'actualSleepHours': 7,
        'actualFocusHours': 3,
        'overallScore': 72.5,
        'screenTimeScore': 60,
        'performanceLevel': 'Good',
      }, documentId: '2026-10-10');
      expect(saved.overallScore, 72.5);
      expect(saved.componentScores['lowDistraction'], 60);
      expect(saved.coverage, isNull);
    });
  });
}
