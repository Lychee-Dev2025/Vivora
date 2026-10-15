import 'dart:math' as math;

import '../../activity_monitoring/data/models/activity_date_utils.dart';
import 'behavior_models.dart';
import 'behavior_thresholds.dart';

/// Pure statistics used by the engine. No I/O, no clocks.
class BehaviorStats {
  const BehaviorStats._();

  static double? mean(Iterable<double> values) {
    final List<double> list = values.toList();
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  /// Population standard deviation.
  static double? standardDeviation(Iterable<double> values) {
    final List<double> list = values.toList();
    if (list.length < 2) return null;
    final double m = mean(list)!;
    return math.sqrt(mean(list.map((v) => (v - m) * (v - m)))!);
  }

  /// Pearson correlation, or null when there are fewer than [minPairs] pairs
  /// or either side has no variation (r would be undefined).
  static double? pearson(
    List<double> xs,
    List<double> ys, {
    required int minPairs,
  }) {
    if (xs.length != ys.length || xs.length < minPairs) return null;
    final double mx = mean(xs)!;
    final double my = mean(ys)!;
    double sxy = 0, sxx = 0, syy = 0;
    for (int i = 0; i < xs.length; i++) {
      final double dx = xs[i] - mx;
      final double dy = ys[i] - my;
      sxy += dx * dy;
      sxx += dx * dx;
      syy += dy * dy;
    }
    if (sxx <= 1e-12 || syy <= 1e-12) return null;
    return (sxy / math.sqrt(sxx * syy)).clamp(-1.0, 1.0);
  }

  static MetricStats describe({
    required String metric,
    required String unit,
    required DataSource source,
    required List<DailyValue> values,
    required int periodDays,
    int minSamplesForAverage = 1,
  }) {
    if (values.isEmpty) {
      return MetricStats(
        metric: metric,
        unit: unit,
        source: source,
        count: 0,
        periodDays: periodDays,
      );
    }
    final List<DailyValue> sorted = List<DailyValue>.of(values)
      ..sort((a, b) => a.value.compareTo(b.value));
    final List<double> raw = values.map((v) => v.value).toList();
    final bool enough = values.length >= minSamplesForAverage;
    return MetricStats(
      metric: metric,
      unit: unit,
      source: source,
      count: values.length,
      periodDays: periodDays,
      mean: enough ? mean(raw) : null,
      total: raw.reduce((a, b) => a + b),
      // Ties resolve to the most recent day.
      min: _lastOf(values, sorted.first.value),
      max: _lastOf(values, sorted.last.value),
      standardDeviation: standardDeviation(raw),
    );
  }

  static DailyValue _lastOf(List<DailyValue> values, double target) {
    DailyValue? best;
    for (final DailyValue v in values) {
      if (v.value == target && (best == null || v.date.isAfter(best.date))) {
        best = v;
      }
    }
    return best!;
  }

  /// Classifies the change from [previous] to [current]. Both sides need
  /// `minSamplesPerTrendSide` valid days; the change must exceed both the
  /// relative threshold and [absoluteFloor] to be called a trend.
  static TrendResult trend({
    required String metric,
    required String unit,
    required DataSource source,
    required List<double> current,
    required List<double> previous,
    required String basis,
    required double absoluteFloor,
    required BehaviorThresholds thresholds,
  }) {
    final double? cur = mean(current);
    final double? prev = mean(previous);
    TrendDirection direction;
    double? ratio;
    if (current.length < thresholds.minSamplesPerTrendSide ||
        previous.length < thresholds.minSamplesPerTrendSide ||
        cur == null ||
        prev == null) {
      direction = TrendDirection.insufficientData;
    } else {
      final double diff = cur - prev;
      ratio = prev.abs() < 1e-9 ? null : diff / prev;
      final bool relativeOk =
          ratio == null || ratio.abs() >= thresholds.relativeTrendChange;
      final bool absoluteOk = diff.abs() >= absoluteFloor;
      direction = relativeOk && absoluteOk
          ? (diff > 0 ? TrendDirection.increasing : TrendDirection.decreasing)
          : TrendDirection.stable;
    }
    return TrendResult(
      metric: metric,
      unit: unit,
      source: source,
      direction: direction,
      basis: basis,
      currentMean: cur,
      previousMean: prev,
      currentSamples: current.length,
      previousSamples: previous.length,
      changeRatio: ratio,
    );
  }

  /// Longest run of consecutive calendar days among [dayKeys]
  /// (`yyyy-MM-dd`). Duplicate keys count once.
  static int bestStreak(Iterable<String> dayKeys) {
    final List<DateTime> days =
        dayKeys
            .toSet()
            .map(ActivityDateUtils.parseKey)
            .whereType<DateTime>()
            .toList()
          ..sort();
    int best = 0, run = 0;
    DateTime? previous;
    for (final DateTime day in days) {
      final bool next =
          previous != null &&
          ActivityDateUtils.dayKey(
                DateTime(previous.year, previous.month, previous.day + 1),
              ) ==
              ActivityDateUtils.dayKey(day);
      run = next ? run + 1 : 1;
      best = math.max(best, run);
      previous = day;
    }
    return best;
  }

  /// Consecutive days ending today, or yesterday when today is not logged yet.
  static int currentStreak(Iterable<String> dayKeys, DateTime today) {
    final Set<String> keys = dayKeys.toSet();
    DateTime cursor = ActivityDateUtils.dayStart(today);
    if (!keys.contains(ActivityDateUtils.dayKey(cursor))) {
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    int streak = 0;
    while (keys.contains(ActivityDateUtils.dayKey(cursor))) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return streak;
  }

  static String percent(double ratio) {
    final int p = (ratio * 100).round();
    return '${p > 0 ? '+' : ''}$p%';
  }
}
