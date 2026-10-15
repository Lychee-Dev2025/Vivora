import 'dart:math' as math;

import '../../activity_monitoring/data/models/activity_date_utils.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../../focus_mode/data/focus_session_repository.dart';
import '../../insights/data/history_data.dart';
import 'behavior_models.dart';
import 'behavior_stats.dart';
import 'behavior_thresholds.dart';
import 'history_normalizer.dart';

/// Definition of one analysed metric.
class _Metric {
  const _Metric(
    this.id,
    this.label,
    this.unit,
    this.source,
    this.read, {
    required this.floor,
    this.measured = false,
  });

  final String id;
  final String label;
  final String unit;
  final DataSource source;
  final double? Function(DayRecord r) read;

  /// Smallest absolute change that can count as a trend.
  final double floor;

  /// Measured values from today are partial and excluded from multi-day
  /// comparisons.
  final bool measured;
}

/// Module 3: behaviour analysis and habit detection.
///
/// Pure and deterministic: the same [HistoryData] always gives the same
/// result, nothing is random, and nothing is read from widgets. Every rule's
/// threshold lives in [BehaviorThresholds].
///
/// Principles:
///  * only validated observations are used ([HistoryNormalizer]); a missing
///    value is "not recorded", never zero;
///  * measured (Android), tracked (Focus Mode) and self-reported (daily log)
///    values are kept apart and labelled;
///  * recurring patterns need enough days ([BehaviorThresholds]); a single day
///    only yields "single-day observations";
///  * relationships are described as associations, never causes;
///  * time-of-day claims are only made from timestamped focus sessions.
class BehaviorAnalysisEngine {
  const BehaviorAnalysisEngine({
    this.thresholds = const BehaviorThresholds(),
    this.normalizer = const HistoryNormalizer(),
  });

  final BehaviorThresholds thresholds;
  final HistoryNormalizer normalizer;

  /// Analyses every period from one normalisation pass.
  Map<AnalysisPeriod, BehaviorAnalysis> analyzeAll(
    HistoryData history, {
    DateTime? calculatedAt,
  }) {
    final NormalizedHistory data = normalizer.normalize(history);
    final DateTime at = calculatedAt ?? history.today;
    return <AnalysisPeriod, BehaviorAnalysis>{
      for (final AnalysisPeriod p in AnalysisPeriod.values)
        p: _analyze(data, p, at),
    };
  }

  BehaviorAnalysis analyze(
    HistoryData history,
    AnalysisPeriod period, {
    DateTime? calculatedAt,
  }) {
    return _analyze(
      normalizer.normalize(history),
      period,
      calculatedAt ?? history.today,
    );
  }

  static final List<_Metric> _metrics = <_Metric>[
    _Metric(
      'appUsageMinutes',
      'Measured app usage',
      'minutes',
      DataSource.measured,
      (r) => r.appUsageMinutes,
      floor: 10,
      measured: true,
    ),
    _Metric(
      'screenUnlockedMinutes',
      'Screen unlocked time',
      'minutes',
      DataSource.measured,
      (r) => r.screenUnlockedMinutes,
      floor: 10,
      measured: true,
    ),
    _Metric(
      'unlocks',
      'Phone unlocks',
      'count',
      DataSource.measured,
      (r) => r.unlocks,
      floor: 5,
      measured: true,
    ),
    _Metric(
      'productiveAppMinutes',
      'Productive app time',
      'minutes',
      DataSource.measured,
      (r) => r.productiveMinutes,
      floor: 10,
      measured: true,
    ),
    _Metric(
      'distractingAppMinutes',
      'Distracting app time',
      'minutes',
      DataSource.measured,
      (r) => r.distractingMinutes,
      floor: 10,
      measured: true,
    ),
    _Metric(
      'neutralAppMinutes',
      'Neutral app time',
      'minutes',
      DataSource.measured,
      (r) => r.neutralMinutes,
      floor: 10,
      measured: true,
    ),
    _Metric(
      'uncategorizedAppMinutes',
      'Uncategorized app time',
      'minutes',
      DataSource.measured,
      (r) => r.uncategorizedMinutes,
      floor: 10,
      measured: true,
    ),
    _Metric(
      'sensorActiveMinutes',
      'Measured walking/running',
      'minutes',
      DataSource.measured,
      (r) => r.sensorActiveMinutes,
      floor: 10,
      measured: true,
    ),
    _Metric(
      'loggedScreenHours',
      'Logged screen time',
      'hours',
      DataSource.selfReported,
      (r) => r.loggedScreenHours,
      floor: 0.25,
    ),
    _Metric(
      'studyHours',
      'Logged study time',
      'hours',
      DataSource.selfReported,
      (r) => r.studyHours,
      floor: 0.25,
    ),
    _Metric(
      'deepFocusHours',
      'Logged deep focus',
      'hours',
      DataSource.selfReported,
      (r) => r.deepFocusHours,
      floor: 0.25,
    ),
    // Focus Mode only records time when a session runs, so a day with any
    // other record and no session genuinely had 0 tracked focus minutes.
    _Metric(
      'focusSessionMinutes',
      'Focus Mode time',
      'minutes',
      DataSource.tracked,
      (r) => r.focusSessionMinutes,
      floor: 10,
    ),
    _Metric(
      'sleepHours',
      'Logged sleep',
      'hours',
      DataSource.selfReported,
      (r) => r.sleepHours,
      floor: 0.25,
    ),
    _Metric(
      'routineRating',
      'Routine consistency rating',
      'rating',
      DataSource.selfReported,
      (r) => r.routineRating,
      floor: 5,
    ),
    _Metric(
      'activityRating',
      'Physical activity rating',
      'rating',
      DataSource.selfReported,
      (r) => r.activityRating,
      floor: 5,
    ),
    _Metric(
      'score',
      'Productivity score',
      'points',
      DataSource.mixed,
      (r) => r.score,
      floor: 5,
    ),
  ];

  static _Metric _metric(String id) => _metrics.firstWhere((m) => m.id == id);

  BehaviorAnalysis _analyze(
    NormalizedHistory data,
    AnalysisPeriod period,
    DateTime calculatedAt,
  ) {
    final DateTime today = data.today;
    final List<DateTime> window = ActivityDateUtils.lastDays(
      today,
      period.days,
    );
    final List<String> keys = window.map(ActivityDateUtils.dayKey).toList();
    final DateTime previousEnd = DateTime(
      today.year,
      today.month,
      today.day - period.days,
    );
    final List<String> previousKeys = period == AnalysisPeriod.day
        ? const <String>[]
        : ActivityDateUtils.lastDays(
            previousEnd,
            period.days,
          ).map(ActivityDateUtils.dayKey).toList();
    final bool multiDay = period != AnalysisPeriod.day;

    List<DailyValue> series(_Metric m, List<String> dayKeys) {
      final List<DailyValue> out = <DailyValue>[];
      for (final String key in dayKeys) {
        final DayRecord? r = data.day(key);
        if (r == null) continue;
        if (m.measured &&
            (!r.hasMeasurement || (multiDay && !r.measurementComplete))) {
          continue;
        }
        final double? v = m.read(r);
        if (v != null) out.add(DailyValue(key, r.date, v));
      }
      return out;
    }

    // --- Statistics and trends ---------------------------------------------
    final Map<String, MetricStats> stats = <String, MetricStats>{};
    final Map<String, TrendResult> trends = <String, TrendResult>{};
    for (final _Metric m in _metrics) {
      final List<DailyValue> current = series(m, keys);
      stats[m.id] = BehaviorStats.describe(
        metric: m.id,
        unit: m.unit,
        source: m.source,
        values: current,
        periodDays: period.days,
        minSamplesForAverage: thresholds.minSamplesForAverage.clamp(
          1,
          period.days,
        ),
      );
      if (!multiDay) continue;
      List<double> now = current.map((v) => v.value).toList();
      List<double> before = series(
        m,
        previousKeys,
      ).map((v) => v.value).toList();
      String basis = 'previous ${period.days} days';
      if (before.length < thresholds.minSamplesPerTrendSide &&
          period == AnalysisPeriod.month) {
        // Not enough of the previous month: compare the halves of this one.
        final int half = keys.length ~/ 2;
        final Set<String> first = keys.take(half).toSet();
        before = current
            .where((v) => first.contains(v.dayKey))
            .map((v) => v.value)
            .toList();
        now = current
            .where((v) => !first.contains(v.dayKey))
            .map((v) => v.value)
            .toList();
        basis = 'first vs second half of the last 30 days';
      }
      trends[m.id] = BehaviorStats.trend(
        metric: m.id,
        unit: m.unit,
        source: m.source,
        current: now,
        previous: before,
        basis: basis,
        absoluteFloor: m.floor,
        thresholds: thresholds,
      );
    }

    // --- Goals -------------------------------------------------------------
    final HistoryGoals g = data.goals;
    GoalAchievement? goal(
      String id,
      double? target,
      String metricId,
      bool isLimit,
      double factor,
    ) {
      if (target == null) return null;
      final _Metric m = _metric(metricId);
      final List<DailyValue> values = series(m, keys);
      final int met = values
          .where(
            (v) => isLimit
                ? v.value <= target * factor
                : v.value >= target * factor,
          )
          .length;
      return GoalAchievement(
        goal: id,
        target: target,
        unit: 'hours',
        isLimit: isLimit,
        source: m.source,
        metDays: met,
        observedDays: values.length,
      );
    }

    final List<GoalAchievement> goals = <GoalAchievement?>[
      goal('sleep', g.sleepHours, 'sleepHours', false, 1),
      goal('study', g.studyHours, 'studyHours', false, 1),
      goal('focus', g.focusHours, 'deepFocusHours', false, 1),
      // Measured app usage is in minutes; the limit is in hours.
      goal('appUsageLimit', g.screenLimitHours, 'appUsageMinutes', true, 60),
      goal(
        'loggedScreenLimit',
        g.screenLimitHours,
        'loggedScreenHours',
        true,
        1,
      ),
    ].whereType<GoalAchievement>().toList();

    // --- Apps ----------------------------------------------------------------
    final List<AppUsagePattern> apps = _apps(data, keys, multiDay);

    // --- Logging consistency -------------------------------------------------
    final Set<String> loggedKeys = data.days.values
        .where((r) => r.hasLog)
        .map((r) => r.dayKey)
        .toSet();
    final int loggedInPeriod = keys.where(loggedKeys.contains).length;
    final int measuredInPeriod = keys.where((k) {
      final DayRecord? r = data.day(k);
      return r != null &&
          r.hasMeasurement &&
          (!multiDay || r.measurementComplete);
    }).length;

    // --- Habits --------------------------------------------------------------
    final _HabitBuilder hb = _HabitBuilder(period, calculatedAt, thresholds);
    if (multiDay) {
      _detectHabits(
        hb,
        data,
        period,
        keys,
        stats,
        trends,
        goals,
        apps,
        loggedInPeriod,
        loggedKeys,
      );
    } else {
      _singleDay(hb, data, keys.single, goals, apps);
    }

    // --- Relationships -------------------------------------------------------
    final List<BehaviorRelationship> relationships = multiDay
        ? _relationships(data, keys)
        : const <BehaviorRelationship>[];

    // --- Data quality --------------------------------------------------------
    final Map<String, String> missing = <String, String>{
      'app_time_of_day':
          'App usage is stored as daily totals per app, so the time of day apps are used cannot be determined.',
      'sleep_times':
          'Only sleep duration is logged; bedtime and wake-up time are not recorded.',
    };
    if (stats['sensorActiveMinutes']!.count == 0) {
      missing['movement_sensor'] =
          'No movement sensor readings in this period; physical activity uses your self-ratings only.';
    }
    if (g.sleepHours == null &&
        g.studyHours == null &&
        g.focusHours == null &&
        g.screenLimitHours == null) {
      missing['goals'] =
          'No goals are set, so goal achievement cannot be measured.';
    }
    if (loggedInPeriod == 0) {
      missing['daily_logs'] = 'No daily progress logs in this period.';
    }
    if (measuredInPeriod == 0) {
      missing['measured_usage'] = multiDay
          ? 'No complete days of measured phone usage in this period.'
          : 'No measured phone usage for today yet.';
    }

    return BehaviorAnalysis(
      period: period,
      start: window.first,
      end: window.last,
      calculatedAt: calculatedAt,
      metrics: stats,
      trends: trends,
      goals: goals,
      apps: apps,
      habits: hb.sorted(),
      relationships: relationships,
      dataQuality: DataQualityReport(
        excludedRecords: Map<String, int>.unmodifiable(data.excluded),
        warnings: List<String>.unmodifiable(data.warnings),
        missing: missing,
        loggedDays: loggedInPeriod,
        measuredDays: measuredInPeriod,
        periodDays: period.days,
      ),
      loggingStreak: BehaviorStats.currentStreak(loggedKeys, today),
      bestLoggingStreak: BehaviorStats.bestStreak(loggedKeys),
    );
  }

  List<AppUsagePattern> _apps(
    NormalizedHistory data,
    List<String> keys,
    bool multiDay,
  ) {
    final Map<String, AppDay> latest = <String, AppDay>{};
    final Map<String, double> total = <String, double>{};
    final Map<String, int> used = <String, int>{};
    final Map<String, int> heavy = <String, int>{};
    int observed = 0;
    for (final String key in keys) {
      final DayRecord? r = data.day(key);
      if (r == null || r.apps == null || (multiDay && !r.measurementComplete)) {
        continue;
      }
      observed++;
      for (final AppDay a in r.apps!) {
        latest[a.packageName] = a;
        total[a.packageName] = (total[a.packageName] ?? 0) + a.minutes;
        if (a.minutes > 0) used[a.packageName] = (used[a.packageName] ?? 0) + 1;
        if (a.minutes >= thresholds.repeatedAppMinutes) {
          heavy[a.packageName] = (heavy[a.packageName] ?? 0) + 1;
        }
      }
    }
    final List<AppUsagePattern> out = <AppUsagePattern>[
      for (final String pkg in total.keys)
        AppUsagePattern(
          packageName: pkg,
          appName: latest[pkg]!.appName,
          category: latest[pkg]!.category.value,
          categoryIsUserChoice: latest[pkg]!.categoryIsUserChoice,
          totalMinutes: total[pkg]!,
          daysUsed: used[pkg] ?? 0,
          daysUsedHeavily: heavy[pkg] ?? 0,
          observedDays: observed,
        ),
    ]..sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
    return out.take(15).toList();
  }

  void _singleDay(
    _HabitBuilder hb,
    NormalizedHistory data,
    String key,
    List<GoalAchievement> goals,
    List<AppUsagePattern> apps,
  ) {
    final DayRecord? r = data.day(key);
    if (r == null) return;
    if (r.score != null) {
      hb.add(
        id: 'today_score',
        title:
            'Today\'s score: ${r.score!.round()}${r.performanceLevel == null ? '' : ' (${r.performanceLevel})'}',
        description: 'From the daily log you saved today.',
        metric: 'score',
        evidence: <String>['Single day only; not a pattern.'],
        source: DataSource.mixed,
        polarity: InsightPolarity.informational,
        samples: 1,
        singleDay: true,
        value: r.score,
      );
    }
    for (final GoalAchievement goal in goals) {
      if (goal.observedDays == 0 || goal.goal == 'loggedScreenLimit') continue;
      final bool met = goal.metDays == 1;
      final String what = switch (goal.goal) {
        'sleep' => 'Sleep goal',
        'study' => 'Study goal',
        'focus' => 'Deep focus goal',
        _ => 'Screen-time limit',
      };
      final bool partial = goal.goal == 'appUsageLimit';
      hb.add(
        id: 'today_goal_${goal.goal}',
        title: partial
            ? (met
                  ? '$what: within limit so far'
                  : '$what: already exceeded today')
            : (met ? '$what met today' : '$what not met today'),
        description: partial
            ? 'Measured app usage so far today against your ${_h(goal.target)} limit.'
            : 'Based on today\'s saved log (self-reported).',
        metric: goal.goal,
        evidence: <String>['Single day only; not a pattern.'],
        source: goal.source,
        polarity: met ? InsightPolarity.positive : InsightPolarity.negative,
        samples: 1,
        singleDay: true,
      );
    }
    if (r.focusSessions > 0) {
      hb.add(
        id: 'today_focus_sessions',
        title:
            '${r.focusSessions} focus session${r.focusSessions == 1 ? '' : 's'} today',
        description:
            '${formatMinutes(r.focusSessionMinutes.round())} recorded by Focus Mode.',
        metric: 'focusSessionMinutes',
        evidence: <String>['${r.completedFocusSessions} completed in full.'],
        source: DataSource.tracked,
        polarity: InsightPolarity.positive,
        samples: 1,
        singleDay: true,
      );
    }
    if (apps.isNotEmpty && r.appUsageMinutes != null) {
      final AppUsagePattern top = apps.first;
      hb.add(
        id: 'today_top_app',
        title: 'Most used app so far: ${top.appName}',
        description:
            '${formatMinutes(top.totalMinutes.round())} of ${formatMinutes(r.appUsageMinutes!.round())} measured app usage today (${top.category}).',
        metric: 'appUsageMinutes',
        evidence: <String>['Today is still in progress.'],
        source: DataSource.measured,
        polarity: InsightPolarity.informational,
        samples: 1,
        singleDay: true,
        packageName: top.packageName,
      );
    }
  }

  void _detectHabits(
    _HabitBuilder hb,
    NormalizedHistory data,
    AnalysisPeriod period,
    List<String> keys,
    Map<String, MetricStats> stats,
    Map<String, TrendResult> trends,
    List<GoalAchievement> goals,
    List<AppUsagePattern> apps,
    int loggedInPeriod,
    Set<String> loggedKeys,
  ) {
    final BehaviorThresholds t = thresholds;
    final String span = period.label.toLowerCase();

    // Logging consistency (how regularly progress is recorded).
    final double loggedShare = loggedInPeriod / period.days;
    final bool regular = period == AnalysisPeriod.week
        ? loggedInPeriod >= t.regularLoggingDaysPerWeek
        : loggedShare >= t.habitShare;
    if (regular && loggedInPeriod >= t.minSamplesForPattern) {
      hb.add(
        id: 'regular_logging',
        title: 'Consistent daily logging',
        description:
            'You saved a progress log on $loggedInPeriod of the $span.',
        metric: 'loggedDays',
        evidence: <String>[
          '$loggedInPeriod of ${period.days} calendar days have a saved log.',
        ],
        source: DataSource.selfReported,
        polarity: InsightPolarity.positive,
        samples: loggedInPeriod,
      );
    } else {
      final List<String> earlier = loggedKeys
          .where((k) => k.compareTo(keys.first) < 0)
          .toList();
      final double weekly = loggedInPeriod * 7 / period.days;
      if (earlier.isNotEmpty && weekly <= t.irregularLoggingDaysPerWeek) {
        hb.add(
          id: 'irregular_logging',
          title: 'Logging has become irregular',
          description:
              'Only $loggedInPeriod of the $span have a saved log, so trends are less reliable.',
          metric: 'loggedDays',
          evidence: <String>[
            '$loggedInPeriod of ${period.days} days logged; you have logs before this period.',
          ],
          source: DataSource.selfReported,
          polarity: InsightPolarity.negative,
          samples: loggedInPeriod,
        );
      }
    }

    // Goal achievement (study, sleep, focus, measured screen-time limit).
    for (final GoalAchievement goal in goals) {
      if (goal.goal == 'loggedScreenLimit') continue;
      final int n = goal.observedDays;
      if (n < t.minSamplesForPattern) continue;
      final double rate = goal.rate!;
      final String name = switch (goal.goal) {
        'sleep' => 'sleep goal',
        'study' => 'study goal',
        'focus' => 'deep focus goal',
        _ => 'screen-time limit',
      };
      final String target = goal.isLimit
          ? '≤ ${_h(goal.target)} of measured app usage'
          : _h(goal.target);
      final String evidence =
          '${goal.isLimit ? 'Within' : 'Met'} on ${goal.metDays} of $n ${goal.source == DataSource.measured ? 'measured' : 'logged'} days ($target).';
      if (rate >= t.habitShare) {
        hb.add(
          id: '${goal.goal}_goal_met',
          title: goal.isLimit
              ? 'Usually within your $name'
              : 'Repeatedly meeting your $name',
          description: evidence,
          metric: goal.goal,
          evidence: <String>[evidence],
          source: goal.source,
          polarity: InsightPolarity.positive,
          samples: n,
        );
      } else if (rate <= 1 - t.habitShare) {
        hb.add(
          id: '${goal.goal}_goal_missed',
          title: goal.isLimit
              ? 'Screen-time limit exceeded on most days'
              : 'Often missing your $name',
          description: goal.isLimit
              ? 'Exceeded on ${n - goal.metDays} of $n measured days ($target).'
              : 'Missed on ${n - goal.metDays} of $n logged days (goal $target).',
          metric: goal.goal,
          evidence: <String>[evidence],
          source: goal.source,
          polarity: InsightPolarity.negative,
          samples: n,
        );
      }
    }

    // Study logging consistency (self-reported study hours > 0).
    final MetricStats study = stats['studyHours']!;
    if (study.count >= t.minSamplesForHabit) {
      final int studied = keys
          .where((k) => (data.day(k)?.studyHours ?? 0) > 0)
          .length;
      if (studied / study.count >= t.habitShare) {
        hb.add(
          id: 'consistent_study',
          title: 'Studying consistently',
          description:
              'Study time logged on $studied of ${study.count} logged days, averaging ${_h(study.mean!)} per day.',
          metric: 'studyHours',
          evidence: <String>[
            'Total ${_h(study.total!)} over $span (self-reported).',
          ],
          source: DataSource.selfReported,
          polarity: InsightPolarity.positive,
          samples: study.count,
        );
      }
    }

    // Sleep consistency (spread of logged sleep duration).
    final MetricStats sleep = stats['sleepHours']!;
    if (sleep.count >= t.minSamplesForHabit &&
        sleep.standardDeviation! <= t.consistentSleepSdHours) {
      hb.add(
        id: 'consistent_sleep',
        title: 'Consistent sleep duration',
        description:
            'Your logged sleep stays close to ${_h(sleep.mean!)} (typically within ${_h(sleep.standardDeviation!)}).',
        metric: 'sleepHours',
        evidence: <String>[
          '${sleep.count} logged nights; shortest ${_h(sleep.min!.value)}, longest ${_h(sleep.max!.value)}.',
        ],
        source: DataSource.selfReported,
        polarity: InsightPolarity.positive,
        samples: sleep.count,
      );
    }
    _sleepConsistencyChange(hb, data, period, keys);

    // Frequent distracting apps (respecting the user's categories).
    for (final AppUsagePattern app in apps) {
      if (app.category != AppCategory.distracting.value ||
          app.observedDays < t.minSamplesForPattern) {
        continue;
      }
      final double share = app.daysUsedHeavily / app.observedDays;
      if (app.daysUsedHeavily < t.minSamplesForPattern ||
          share < t.habitShare) {
        continue;
      }
      final bool habit = app.observedDays >= t.minSamplesForHabit;
      hb.add(
        id: 'frequent_distracting_app:${app.packageName}',
        title: habit
            ? 'Daily habit: ${app.appName}'
            : 'Repeated use: ${app.appName}',
        description:
            'Used for ${t.repeatedAppMinutes}+ minutes on ${app.daysUsedHeavily} of ${app.observedDays} measured days '
            '(about ${formatMinutes(app.averagePerObservedDay.round())} per day).',
        metric: 'appUsageMinutes',
        evidence: <String>[
          'Category: distracting${app.categoryIsUserChoice ? ' (your choice)' : ''}.',
          'Total ${formatMinutes(app.totalMinutes.round())} over $span.',
        ],
        source: DataSource.measured,
        polarity: InsightPolarity.negative,
        samples: app.observedDays,
        packageName: app.packageName,
        value: app.averagePerObservedDay,
      );
    }

    // Trends (only when both compared periods have enough valid days).
    void trendHabit(
      String metricId,
      String upId,
      String upTitle,
      InsightPolarity upPolarity,
      String downId,
      String downTitle,
      InsightPolarity downPolarity,
    ) {
      final TrendResult? tr = trends[metricId];
      if (tr == null ||
          (tr.direction != TrendDirection.increasing &&
              tr.direction != TrendDirection.decreasing)) {
        return;
      }
      final bool up = tr.direction == TrendDirection.increasing;
      final _Metric m = _metric(metricId);
      final String change = tr.changeRatio == null
          ? ''
          : ' (${BehaviorStats.percent(tr.changeRatio!)})';
      hb.add(
        id: up ? upId : downId,
        title: up ? upTitle : downTitle,
        description:
            '${m.label} averaged ${_value(tr.currentMean!, m.unit)} vs ${_value(tr.previousMean!, m.unit)}$change, comparing ${tr.basis}.',
        metric: metricId,
        evidence: <String>[
          '${tr.currentSamples} vs ${tr.previousSamples} days with valid ${m.source == DataSource.measured ? 'measurements' : 'records'}.',
        ],
        source: m.source,
        polarity: up ? upPolarity : downPolarity,
        samples: math.min(tr.currentSamples, tr.previousSamples),
        value: tr.changeRatio,
      );
    }

    trendHabit(
      'appUsageMinutes',
      'measured_app_usage_increasing',
      'Measured app usage is increasing',
      InsightPolarity.negative,
      'measured_app_usage_decreasing',
      'Measured app usage is decreasing',
      InsightPolarity.positive,
    );
    trendHabit(
      'distractingAppMinutes',
      'distracting_usage_increasing',
      'More time in distracting apps',
      InsightPolarity.negative,
      'distracting_usage_decreasing',
      'Less time in distracting apps',
      InsightPolarity.positive,
    );
    trendHabit(
      'deepFocusHours',
      'focus_improving',
      'Logged deep focus is improving',
      InsightPolarity.positive,
      'focus_declining',
      'Logged deep focus is declining',
      InsightPolarity.negative,
    );
    trendHabit(
      'focusSessionMinutes',
      'focus_sessions_increasing',
      'More Focus Mode time',
      InsightPolarity.positive,
      'focus_sessions_decreasing',
      'Less Focus Mode time',
      InsightPolarity.negative,
    );
    trendHabit(
      'studyHours',
      'study_increasing',
      'Logged study time is rising',
      InsightPolarity.positive,
      'study_decreasing',
      'Logged study time is falling',
      InsightPolarity.negative,
    );
    trendHabit(
      'score',
      'productivity_improving',
      'Productivity scores are improving',
      InsightPolarity.positive,
      'productivity_declining',
      'Productivity scores are declining',
      InsightPolarity.negative,
    );
    trendHabit(
      'routineRating',
      'routine_improving',
      'Routine consistency improving',
      InsightPolarity.positive,
      'routine_declining',
      'Routine consistency declining',
      InsightPolarity.negative,
    );

    // Productivity: steadiness and productive-day share (existing levels).
    final MetricStats score = stats['score']!;
    if (score.count >= t.minSamplesForHabit &&
        score.mean! > 0 &&
        score.standardDeviation! / score.mean! <= t.consistentScoreCv) {
      hb.add(
        id: 'steady_productivity',
        title: 'Steady productivity (average ${score.mean!.round()})',
        description:
            'Your scores vary by only about ${score.standardDeviation!.round()} points around the average.',
        metric: 'score',
        evidence: <String>[
          '${score.count} scored days; range ${score.min!.value.round()}–${score.max!.value.round()}.',
        ],
        source: DataSource.mixed,
        polarity: InsightPolarity.informational,
        samples: score.count,
      );
    }
    if (score.count >= t.minSamplesForPattern) {
      final List<DayRecord> scored = keys
          .map(data.day)
          .whereType<DayRecord>()
          .where((r) => r.score != null)
          .toList();
      final int productive = scored
          .where(
            (r) =>
                r.performanceLevel == 'Excellent' ||
                r.performanceLevel == 'Good',
          )
          .length;
      hb.add(
        id: 'productive_day_share',
        title:
            '$productive of ${scored.length} scored days were Good or Excellent',
        description:
            'Average score ${score.mean!.round()}; best ${score.max!.value.round()} on ${_dayLabel(score.max!.date)}, '
            'lowest ${score.min!.value.round()} on ${_dayLabel(score.min!.date)}.',
        metric: 'score',
        evidence: <String>[
          'Levels use the existing thresholds (Good ≥ 70, Excellent ≥ 85).',
        ],
        source: DataSource.mixed,
        polarity: productive * 2 >= scored.length
            ? InsightPolarity.positive
            : InsightPolarity.informational,
        samples: scored.length,
      );
    }

    // Routine consistency rating (self-assessment, distinct from logging).
    final MetricStats routine = stats['routineRating']!;
    if (routine.count >= t.minSamplesForHabit) {
      final int high = keys
          .where(
            (k) => (data.day(k)?.routineRating ?? -1) >= t.highRoutineRating,
          )
          .length;
      final int low = keys.where((k) {
        final double? v = data.day(k)?.routineRating;
        return v != null && v < t.lowRoutineRating;
      }).length;
      if (routine.mean! >= t.strongRoutineAverage) {
        hb.add(
          id: 'strong_routine',
          title: 'Strong routine consistency',
          description:
              'You rated your routine ${routine.mean!.round()}% on average; $high high-consistency days.',
          metric: 'routineRating',
          evidence: <String>[
            '${routine.count} self-ratings; $low low days (< ${t.lowRoutineRating.round()}%).',
          ],
          source: DataSource.selfReported,
          polarity: InsightPolarity.positive,
          samples: routine.count,
        );
      } else if (routine.mean! < t.lowRoutineRating) {
        hb.add(
          id: 'weak_routine',
          title: 'Routine is hard to keep',
          description:
              'You rated your routine ${routine.mean!.round()}% on average; $low low days.',
          metric: 'routineRating',
          evidence: <String>['${routine.count} self-ratings.'],
          source: DataSource.selfReported,
          polarity: InsightPolarity.negative,
          samples: routine.count,
        );
      }
    }

    // Physical activity: self-ratings and sensor data kept separate.
    final MetricStats activity = stats['activityRating']!;
    if (activity.count >= t.minSamplesForPattern) {
      final int lowDays = keys.where((k) {
        final double? v = data.day(k)?.activityRating;
        return v != null && v < 40;
      }).length;
      hb.add(
        id: 'activity_rating_summary',
        title: 'Self-rated activity averages ${activity.mean!.round()}%',
        description:
            '$lowDays of ${activity.count} rated days were less active (below 40%).',
        metric: 'activityRating',
        evidence: <String>['Self-reported ratings, not sensor measurements.'],
        source: DataSource.selfReported,
        polarity: activity.mean! >= 60
            ? InsightPolarity.positive
            : InsightPolarity.informational,
        samples: activity.count,
      );
    }
    final MetricStats sensor = stats['sensorActiveMinutes']!;
    if (sensor.count >= t.minSamplesForPattern) {
      hb.add(
        id: 'measured_movement_summary',
        title:
            'Measured walking/running: ${formatMinutes(sensor.mean!.round())} a day',
        description:
            'From the phone\'s activity recognition on ${sensor.count} days.',
        metric: 'sensorActiveMinutes',
        evidence: <String>[
          'Least active: ${_dayLabel(sensor.min!.date)} (${formatMinutes(sensor.min!.value.round())}).',
        ],
        source: DataSource.measured,
        polarity: sensor.mean! >= 30
            ? InsightPolarity.positive
            : InsightPolarity.informational,
        samples: sensor.count,
      );
    }

    // Focus Mode regularity and completion.
    final List<FocusSession> sessions = data.focusSessions
        .where((s) => keys.contains(ActivityDateUtils.dayKey(s.startedAt)))
        .toList();
    final int sessionDays = sessions
        .map((s) => ActivityDateUtils.dayKey(s.startedAt))
        .toSet()
        .length;
    if (sessionDays >= t.minSamplesForPattern) {
      final int completed = sessions.where((s) => s.completed).length;
      hb.add(
        id: 'regular_focus_sessions',
        title: 'Focus sessions on $sessionDays days',
        description:
            '${sessions.length} sessions in $span; $completed completed in full '
            '(${(completed * 100 / sessions.length).round()}%).',
        metric: 'focusSessionMinutes',
        evidence: <String>['Recorded by the Focus Mode timer.'],
        source: DataSource.tracked,
        polarity: sessionDays * 7 / period.days >= 4
            ? InsightPolarity.positive
            : InsightPolarity.informational,
        samples: sessionDays,
      );
    }
    _focusTimeOfDay(hb, sessions, span);
    if (period == AnalysisPeriod.month) _weekdayPatterns(hb, data, keys);
  }

  void _sleepConsistencyChange(
    _HabitBuilder hb,
    NormalizedHistory data,
    AnalysisPeriod period,
    List<String> keys,
  ) {
    final int need = thresholds.minSamplesPerTrendSide + 1;
    List<double> sleepFor(Iterable<String> ks) =>
        ks.map((k) => data.day(k)?.sleepHours).whereType<double>().toList();
    final DateTime prevEnd = DateTime(
      data.today.year,
      data.today.month,
      data.today.day - period.days,
    );
    final List<double> now = sleepFor(keys);
    final List<double> before = sleepFor(
      ActivityDateUtils.lastDays(
        prevEnd,
        period.days,
      ).map(ActivityDateUtils.dayKey),
    );
    if (now.length < need || before.length < need) return;
    final double sdNow = BehaviorStats.standardDeviation(now)!;
    final double sdBefore = BehaviorStats.standardDeviation(before)!;
    final double drop = sdBefore - sdNow;
    if (drop.abs() < 0.25 || drop.abs() < sdBefore * 0.3) return;
    final bool improving = drop > 0;
    hb.add(
      id: improving
          ? 'sleep_consistency_improving'
          : 'sleep_consistency_worsening',
      title: improving
          ? 'Sleep is becoming more regular'
          : 'Sleep is becoming less regular',
      description:
          'Day-to-day variation in logged sleep went from ${_h(sdBefore)} to ${_h(sdNow)} compared with the previous ${period.days} days.',
      metric: 'sleepHours',
      evidence: <String>['${now.length} vs ${before.length} logged nights.'],
      source: DataSource.selfReported,
      polarity: improving ? InsightPolarity.positive : InsightPolarity.negative,
      samples: math.min(now.length, before.length),
    );
  }

  /// Time-of-day claims use only timestamped Focus Mode sessions.
  void _focusTimeOfDay(
    _HabitBuilder hb,
    List<FocusSession> sessions,
    String span,
  ) {
    if (sessions.length < thresholds.minFocusSessionsForTimeOfDay) return;
    String bucket(int hour) => hour >= 5 && hour < 12
        ? 'morning'
        : hour >= 12 && hour < 17
        ? 'afternoon'
        : hour >= 17 && hour < 21
        ? 'evening'
        : 'night';
    final Map<String, double> minutes = <String, double>{};
    double total = 0;
    for (final FocusSession s in sessions) {
      final double m = s.focusedSeconds / 60;
      minutes[bucket(s.startedAt.hour)] =
          (minutes[bucket(s.startedAt.hour)] ?? 0) + m;
      total += m;
    }
    if (total <= 0) return;
    final MapEntry<String, double> top = minutes.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    final double share = top.value / total;
    if (share < thresholds.timeOfDayShare) return;
    hb.add(
      id: 'focus_time_of_day',
      title: 'You focus most in the ${top.key}',
      description:
          '${(share * 100).round()}% of your Focus Mode time in $span started in the ${top.key}.',
      metric: 'focusSessionMinutes',
      evidence: <String>[
        '${sessions.length} timed sessions (morning 5–12, afternoon 12–17, evening 17–21, night 21–5).',
      ],
      source: DataSource.tracked,
      polarity: InsightPolarity.informational,
      samples: sessions.length,
    );
  }

  void _weekdayPatterns(
    _HabitBuilder hb,
    NormalizedHistory data,
    List<String> keys,
  ) {
    const List<String> names = <String>[
      'Mondays',
      'Tuesdays',
      'Wednesdays',
      'Thursdays',
      'Fridays',
      'Saturdays',
      'Sundays',
    ];
    for (final (String id, bool higherIsBetter) in <(String, bool)>[
      ('score', true),
      ('deepFocusHours', true),
      ('appUsageMinutes', false),
    ]) {
      final _Metric m = _metric(id);
      final Map<int, List<double>> byDay = <int, List<double>>{};
      final List<double> all = <double>[];
      for (final String key in keys) {
        final DayRecord? r = data.day(key);
        if (r == null) continue;
        if (m.measured && !r.measurementComplete) continue;
        final double? v = m.read(r);
        if (v == null) continue;
        byDay.putIfAbsent(r.date.weekday, () => <double>[]).add(v);
        all.add(v);
      }
      final Map<int, List<double>> eligible =
          Map<int, List<double>>.fromEntries(
            byDay.entries.where(
              (e) => e.value.length >= thresholds.minWeeksForWeekdayPattern,
            ),
          );
      if (eligible.length < thresholds.minWeekdaysCompared) continue;
      final double overall = BehaviorStats.mean(all)!;
      if (overall <= 0) continue;
      final MapEntry<int, List<double>> top = eligible.entries.reduce(
        (a, b) => BehaviorStats.mean(a.value)! >= BehaviorStats.mean(b.value)!
            ? a
            : b,
      );
      final double topMean = BehaviorStats.mean(top.value)!;
      if (topMean < overall * (1 + thresholds.weekdayLift)) continue;
      hb.add(
        id: 'weekday_pattern:$id',
        title: '${m.label} is higher on ${names[top.key - 1]}',
        description:
            '${names[top.key - 1]} average ${_value(topMean, m.unit)} vs ${_value(overall, m.unit)} overall in the last 30 days.',
        metric: id,
        evidence: <String>[
          '${top.value.length} ${names[top.key - 1]} compared across ${eligible.length} weekdays with enough data.',
        ],
        source: m.source,
        polarity: higherIsBetter
            ? InsightPolarity.positive
            : InsightPolarity.informational,
        samples: top.value.length,
      );
    }
  }

  /// Association of each behaviour with the productivity score on the same
  /// (valid, paired) days.
  List<BehaviorRelationship> _relationships(
    NormalizedHistory data,
    List<String> keys,
  ) {
    final List<(String, String, bool)> pairsSpec = <(String, String, bool)>[
      ('sleepHours', 'sleep', true),
      ('deepFocusHours', 'deep focus time', true),
      ('focusSessionMinutes', 'Focus Mode time', false),
      ('distractingAppMinutes', 'distracting app time', false),
      ('routineRating', 'routine consistency', true),
      ('activityRating', 'physical activity', true),
    ];
    final List<BehaviorRelationship> out = <BehaviorRelationship>[];
    for (final (String id, String label, bool inFormula) in pairsSpec) {
      final _Metric m = _metric(id);
      final List<double> xs = <double>[];
      final List<double> ys = <double>[];
      for (final String key in keys) {
        final DayRecord? r = data.day(key);
        if (r == null || r.score == null) continue;
        if (m.measured && (!r.hasMeasurement || !r.measurementComplete)) {
          continue;
        }
        if (id == 'focusSessionMinutes' && !r.hasLog) continue;
        final double? x = m.read(r);
        if (x == null) continue;
        xs.add(x);
        ys.add(r.score!);
      }
      final double? rCoef = BehaviorStats.pearson(
        xs,
        ys,
        minPairs: thresholds.minPairsForRelationship,
      );
      String statement;
      if (xs.length < thresholds.minPairsForRelationship) {
        statement =
            'Not enough days with both $label and a score yet (${xs.length} of ${thresholds.minPairsForRelationship} needed).';
      } else if (rCoef == null) {
        statement =
            'No variation in $label or scores across ${xs.length} days, so no relationship can be measured.';
      } else if (rCoef.abs() < thresholds.moderateCorrelation) {
        statement =
            'No clear link between $label and your scores over ${xs.length} days.';
      } else {
        final String strength = rCoef.abs() >= thresholds.strongCorrelation
            ? 'clearly'
            : 'somewhat';
        statement =
            'On recorded days with more $label, your productivity scores $strength tended to be '
            '${rCoef > 0 ? 'higher' : 'lower'} (${xs.length} days).';
      }
      if (inFormula &&
          rCoef != null &&
          rCoef.abs() >= thresholds.moderateCorrelation) {
        statement +=
            ' Note: $label is part of the score calculation, so some link is expected.';
      }
      out.add(
        BehaviorRelationship(
          metric: id,
          pairs: xs.length,
          correlation: rCoef,
          partOfScoreFormula: inFormula,
          statement: statement,
        ),
      );
    }
    return out;
  }

  static String _h(double hours) {
    final int minutes = (hours * 60).round();
    return formatMinutes(minutes);
  }

  static String _value(double v, String unit) => switch (unit) {
    'minutes' => formatMinutes(v.round()),
    'hours' => _h(v),
    'rating' => '${v.round()}%',
    'points' => '${v.round()} points',
    _ => v.round().toString(),
  };

  static String _dayLabel(DateTime d) {
    const List<String> w = <String>[
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    return '${w[d.weekday - 1]} ${d.day}/${d.month}';
  }
}

class _HabitBuilder {
  _HabitBuilder(this.period, this.at, this.t);

  final AnalysisPeriod period;
  final DateTime at;
  final BehaviorThresholds t;
  final List<DetectedHabit> _habits = <DetectedHabit>[];

  void add({
    required String id,
    required String title,
    required String description,
    required String metric,
    required List<String> evidence,
    required DataSource source,
    required InsightPolarity polarity,
    required int samples,
    bool singleDay = false,
    String? packageName,
    double? value,
  }) {
    final EvidenceQuality quality = singleDay || samples < t.minSamplesForHabit
        ? EvidenceQuality.limited
        : samples >= 10 &&
              (source == DataSource.measured || source == DataSource.tracked)
        ? EvidenceQuality.strong
        : EvidenceQuality.moderate;
    final int base = switch (polarity) {
      InsightPolarity.negative => 300,
      InsightPolarity.positive => 200,
      InsightPolarity.informational => 100,
    };
    final int bonus = switch (quality) {
      EvidenceQuality.strong => 30,
      EvidenceQuality.moderate => 20,
      EvidenceQuality.limited => 10,
    };
    _habits.add(
      DetectedHabit(
        id: id,
        title: title,
        description: description,
        metric: metric,
        period: period,
        evidence: <String>[
          ...evidence,
          if (source == DataSource.selfReported)
            'Based on your own daily log entries.',
        ],
        quality: quality,
        polarity: polarity,
        priority: base + bonus + math.min(samples, 30),
        source: source,
        calculatedAt: at,
        sampleSize: samples,
        isSingleDayObservation: singleDay,
        packageName: packageName,
        value: value,
      ),
    );
  }

  List<DetectedHabit> sorted() => List<DetectedHabit>.of(_habits)
    ..sort((a, b) {
      final int byPriority = b.priority.compareTo(a.priority);
      return byPriority != 0 ? byPriority : a.id.compareTo(b.id);
    });
}
