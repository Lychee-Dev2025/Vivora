/// Typed results of the behaviour analysis engine.
///
/// These are the contract for Module 6 (recommendations): everything is plain
/// data with `toMap()`, independent of any widget.
library;

/// The window being analysed, in local calendar days ending today.
enum AnalysisPeriod {
  /// Today only. Produces single-day observations, never habits.
  day(1, 'Today'),
  week(7, 'Last 7 days'),
  month(30, 'Last 30 days');

  const AnalysisPeriod(this.days, this.label);
  final int days;
  final String label;
}

/// Where a value comes from. Self-reported values are never presented as
/// measured ones.
enum DataSource {
  /// Android usage statistics / activity recognition.
  measured,

  /// Recorded automatically by the app (Focus Mode timer).
  tracked,

  /// Entered by the user in the daily log.
  selfReported,

  /// Derived from more than one of the above.
  mixed,
}

enum TrendDirection { increasing, decreasing, stable, insufficientData }

/// Whether a detected behaviour is good, bad or neutral for the user.
enum InsightPolarity { positive, negative, informational }

/// How strong the supporting evidence is.
enum EvidenceQuality {
  /// Few observations or self-reported only: treat as tentative.
  limited,
  moderate,

  /// Many measured observations.
  strong,
}

/// Value of one metric on one local day.
class DailyValue {
  const DailyValue(this.dayKey, this.date, this.value);
  final String dayKey;
  final DateTime date;
  final double value;
}

/// Descriptive statistics over valid observations only.
class MetricStats {
  const MetricStats({
    required this.metric,
    required this.unit,
    required this.source,
    required this.count,
    required this.periodDays,
    this.mean,
    this.total,
    this.min,
    this.max,
    this.standardDeviation,
  });

  final String metric;

  /// 'minutes', 'hours', 'rating', 'points', 'count'.
  final String unit;
  final DataSource source;

  /// Days with a valid value.
  final int count;

  /// Days in the analysed period (count ≤ periodDays; the rest are missing,
  /// never zero).
  final int periodDays;
  final double? mean;
  final double? total;
  final DailyValue? min;
  final DailyValue? max;
  final double? standardDeviation;

  bool get hasData => count > 0;
  int get missingDays => periodDays - count;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'metric': metric,
    'unit': unit,
    'source': source.name,
    'count': count,
    'periodDays': periodDays,
    'mean': mean,
    'total': total,
    'minDay': min?.dayKey,
    'min': min?.value,
    'maxDay': max?.dayKey,
    'max': max?.value,
    'standardDeviation': standardDeviation,
  };
}

/// Comparison of a metric between the analysed period and the one before it
/// (or between the halves of the period when there is no earlier data).
class TrendResult {
  const TrendResult({
    required this.metric,
    required this.unit,
    required this.source,
    required this.direction,
    required this.basis,
    this.currentMean,
    this.previousMean,
    this.currentSamples = 0,
    this.previousSamples = 0,
    this.changeRatio,
  });

  final String metric;
  final String unit;
  final DataSource source;
  final TrendDirection direction;

  /// e.g. 'previous 7 days' or 'first vs second half of the period'.
  final String basis;
  final double? currentMean;
  final double? previousMean;
  final int currentSamples;
  final int previousSamples;

  /// (current − previous) / previous; null when previous is 0 or missing.
  final double? changeRatio;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'metric': metric,
    'unit': unit,
    'source': source.name,
    'direction': direction.name,
    'basis': basis,
    'currentMean': currentMean,
    'previousMean': previousMean,
    'currentSamples': currentSamples,
    'previousSamples': previousSamples,
    'changeRatio': changeRatio,
  };
}

/// How often a configured goal was met on days with a valid observation.
class GoalAchievement {
  const GoalAchievement({
    required this.goal,
    required this.target,
    required this.unit,
    required this.isLimit,
    required this.source,
    required this.metDays,
    required this.observedDays,
  });

  /// 'sleep', 'study', 'focus', 'appUsageLimit', 'loggedScreenLimit'.
  final String goal;
  final double target;
  final String unit;

  /// True for limits (at or below target is "met").
  final bool isLimit;
  final DataSource source;
  final int metDays;
  final int observedDays;

  double? get rate => observedDays == 0 ? null : metDays / observedDays;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'goal': goal,
    'target': target,
    'unit': unit,
    'isLimit': isLimit,
    'source': source.name,
    'metDays': metDays,
    'observedDays': observedDays,
    'rate': rate,
  };
}

/// Association between a behaviour and the productivity score on the same
/// days. Never a causal claim.
class BehaviorRelationship {
  const BehaviorRelationship({
    required this.metric,
    required this.pairs,
    required this.statement,
    this.correlation,
    this.partOfScoreFormula = false,
  });

  final String metric;
  final int pairs;

  /// Pearson r, null when there are too few pairs or no variation.
  final double? correlation;

  /// The metric is itself an input of the score, so some association is
  /// expected by construction.
  final bool partOfScoreFormula;
  final String statement;

  bool get isConclusive => correlation != null;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'metric': metric,
    'pairs': pairs,
    'correlation': correlation,
    'partOfScoreFormula': partOfScoreFormula,
    'statement': statement,
  };
}

/// One detected behaviour (habit, pattern, trend or single-day observation).
class DetectedHabit {
  const DetectedHabit({
    required this.id,
    required this.title,
    required this.description,
    required this.metric,
    required this.period,
    required this.evidence,
    required this.quality,
    required this.polarity,
    required this.priority,
    required this.source,
    required this.calculatedAt,
    required this.sampleSize,
    this.isSingleDayObservation = false,
    this.packageName,
    this.value,
  });

  /// Stable identifier, e.g. `frequent_distracting_app:com.instagram.android`.
  final String id;
  final String title;
  final String description;
  final String metric;
  final AnalysisPeriod period;

  /// Human-readable facts the insight rests on.
  final List<String> evidence;
  final EvidenceQuality quality;
  final InsightPolarity polarity;

  /// Higher shows first.
  final int priority;
  final DataSource source;
  final DateTime calculatedAt;

  /// Number of observations behind the insight.
  final int sampleSize;
  final bool isSingleDayObservation;
  final String? packageName;
  final double? value;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'title': title,
    'description': description,
    'metric': metric,
    'period': period.name,
    'evidence': evidence,
    'quality': quality.name,
    'polarity': polarity.name,
    'priority': priority,
    'source': source.name,
    'calculatedAt': calculatedAt.toIso8601String(),
    'sampleSize': sampleSize,
    'isSingleDayObservation': isSingleDayObservation,
    'packageName': packageName,
    'value': value,
  };
}

/// App-level usage over the period, from measured data.
class AppUsagePattern {
  const AppUsagePattern({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.categoryIsUserChoice,
    required this.totalMinutes,
    required this.daysUsed,
    required this.daysUsedHeavily,
    required this.observedDays,
  });

  final String packageName;
  final String appName;
  final String category;
  final bool categoryIsUserChoice;
  final double totalMinutes;

  /// Days with any usage / with usage ≥ the repeated-use threshold.
  final int daysUsed;
  final int daysUsedHeavily;

  /// Days with app-level data in the period.
  final int observedDays;

  double get averagePerObservedDay =>
      observedDays == 0 ? 0 : totalMinutes / observedDays;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'packageName': packageName,
    'appName': appName,
    'category': category,
    'categoryIsUserChoice': categoryIsUserChoice,
    'totalMinutes': totalMinutes,
    'daysUsed': daysUsed,
    'daysUsedHeavily': daysUsedHeavily,
    'observedDays': observedDays,
  };
}

/// What was excluded and what is missing, so conclusions can be trusted.
class DataQualityReport {
  const DataQualityReport({
    required this.excludedRecords,
    required this.warnings,
    required this.missing,
    required this.loggedDays,
    required this.measuredDays,
    required this.periodDays,
  });

  /// reason → number of records dropped (e.g. 'future_date': 1).
  final Map<String, int> excludedRecords;
  final List<String> warnings;

  /// Things that cannot be analysed with the available data
  /// (e.g. 'app_time_of_day': no per-session timestamps are collected).
  final Map<String, String> missing;
  final int loggedDays;
  final int measuredDays;
  final int periodDays;

  int get excludedTotal =>
      excludedRecords.values.fold<int>(0, (int sum, int v) => sum + v);

  Map<String, dynamic> toMap() => <String, dynamic>{
    'excludedRecords': excludedRecords,
    'warnings': warnings,
    'missing': missing,
    'loggedDays': loggedDays,
    'measuredDays': measuredDays,
    'periodDays': periodDays,
  };
}

/// Complete analysis of one period. This is what Module 6 consumes.
class BehaviorAnalysis {
  const BehaviorAnalysis({
    required this.period,
    required this.start,
    required this.end,
    required this.calculatedAt,
    required this.metrics,
    required this.trends,
    required this.goals,
    required this.apps,
    required this.habits,
    required this.relationships,
    required this.dataQuality,
    required this.loggingStreak,
    required this.bestLoggingStreak,
  });

  final AnalysisPeriod period;

  /// Local midnight of the first and last day analysed.
  final DateTime start;
  final DateTime end;
  final DateTime calculatedAt;

  /// metric id → statistics, e.g. 'sleepHours', 'appUsageMinutes'.
  final Map<String, MetricStats> metrics;
  final Map<String, TrendResult> trends;
  final List<GoalAchievement> goals;

  /// Longest cumulative usage first.
  final List<AppUsagePattern> apps;

  /// Highest priority first.
  final List<DetectedHabit> habits;
  final List<BehaviorRelationship> relationships;
  final DataQualityReport dataQuality;

  /// Consecutive calendar days with a saved log ending today (or yesterday).
  final int loggingStreak;
  final int bestLoggingStreak;

  bool get hasAnyData =>
      dataQuality.loggedDays > 0 || dataQuality.measuredDays > 0;

  DetectedHabit? habit(String id) {
    for (final DetectedHabit h in habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  Iterable<DetectedHabit> habitsWithPrefix(String prefix) =>
      habits.where((DetectedHabit h) => h.id.startsWith(prefix));

  Map<String, dynamic> toMap() => <String, dynamic>{
    'period': period.name,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'calculatedAt': calculatedAt.toIso8601String(),
    'metrics': metrics.map((k, v) => MapEntry(k, v.toMap())),
    'trends': trends.map((k, v) => MapEntry(k, v.toMap())),
    'goals': goals.map((g) => g.toMap()).toList(),
    'apps': apps.map((a) => a.toMap()).toList(),
    'habits': habits.map((h) => h.toMap()).toList(),
    'relationships': relationships.map((r) => r.toMap()).toList(),
    'dataQuality': dataQuality.toMap(),
    'loggingStreak': loggingStreak,
    'bestLoggingStreak': bestLoggingStreak,
  };
}
