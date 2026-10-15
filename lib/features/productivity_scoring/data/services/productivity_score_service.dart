import 'dart:math';

import '../../../first_time_setup/data/models/user_profile_model.dart';
import '../models/productivity_models.dart';

/// Daily productivity score (0-100).
///
/// Weights (project specification):
///   Focus 30% · Sleep 20% · Consistency 20% · Physical Activity 15% ·
///   Low Distraction 15%.
///
/// Component rules:
///  * Focus / Sleep: `min(actual / goal, 1) × 100`.
///  * Consistency: the user's 0-100 self-rating of how well they kept their
///    planned routine.
///  * Physical Activity: the user's 0-100 self-rating; if not given, measured
///    walking+running minutes against 30 min/day (WHO guideline).
///  * Low Distraction: 100 while screen time is within the user's limit, minus
///    20 points per hour over it.
///
/// Missing data: a component whose input (or goal) is missing is left out and
/// the remaining weights are renormalised, so `overall = Σ wᵢsᵢ / Σ wᵢ` over the
/// recorded components. The result reports which components were missing and
/// the covered weight; nothing is ever filled in with an assumed value.
class ProductivityScoreService {
  static const double focusWeight = 0.30;
  static const double sleepWeight = 0.20;
  static const double consistencyWeight = 0.20;
  static const double activityWeight = 0.15;
  static const double lowDistractionWeight = 0.15;

  static const int activeMinutesGoal = 30;
  static const double pointsLostPerHourOverLimit = 20;

  ProductivityScoreResult calculateScore({
    required DailyProductivityLog log,
    required UserProfile profile,
  }) {
    return calculate(log: log, goals: profile.goals);
  }

  ProductivityScoreResult calculate({
    required DailyProductivityLog log,
    required UserGoals goals,
  }) {
    final List<ScoreComponent> components = <ScoreComponent>[
      _ratioComponent(
        key: 'focus',
        label: 'Focus',
        weight: focusWeight,
        actual: log.actualFocusHours,
        goal: parseHours(goals.targetFocusHours),
        unit: 'focus',
      ),
      _ratioComponent(
        key: 'sleep',
        label: 'Sleep',
        weight: sleepWeight,
        actual: log.actualSleepHours,
        goal: parseHours(goals.targetSleepHours),
        unit: 'sleep',
      ),
      _ratingComponent(
        key: 'consistency',
        label: 'Consistency',
        weight: consistencyWeight,
        rating: log.consistencyScore,
      ),
      _activityComponent(log),
      _lowDistractionComponent(
        screenHours: log.actualScreenTimeHours,
        limitHours: parseHours(goals.targetScreenTimeLimit),
      ),
    ];

    final List<ScoreComponent> available = components
        .where((ScoreComponent c) => c.isAvailable)
        .toList();
    double? overall;
    if (available.isNotEmpty) {
      final double weightSum = available.fold<double>(
        0,
        (double sum, ScoreComponent c) => sum + c.weight,
      );
      final double weighted = available.fold<double>(
        0,
        (double sum, ScoreComponent c) => sum + c.weight * c.score!,
      );
      overall = (weighted / weightSum).clamp(0, 100).toDouble();
    }

    final String level = overall == null
        ? 'Not enough data'
        : classify(overall);
    return ProductivityScoreResult(
      overallScore: overall,
      components: components,
      performanceLevel: level,
      feedbackMessage: _feedback(overall, components),
      suggestions: _suggestions(components),
    );
  }

  static String classify(double score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Medium';
    return 'Needs Improvement';
  }

  /// Parses goal strings such as "8h", "7.5 hours", "5h+" (→ 5). Returns null
  /// when there is no usable number or the goal is not positive.
  static double? parseHours(String? text) {
    if (text == null) {
      return null;
    }
    final RegExpMatch? match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    final double? value = match == null
        ? null
        : double.tryParse(match.group(1)!);
    return value == null || value <= 0 ? null : value;
  }

  ScoreComponent _ratioComponent({
    required String key,
    required String label,
    required double weight,
    required double? actual,
    required double? goal,
    required String unit,
  }) {
    if (actual == null) {
      return ScoreComponent(
        key: key,
        label: label,
        weight: weight,
        score: null,
        detail: 'No $unit hours recorded.',
      );
    }
    if (goal == null) {
      return ScoreComponent(
        key: key,
        label: label,
        weight: weight,
        score: null,
        detail: 'No $unit goal set in your profile.',
      );
    }
    final double score = (min(actual / goal, 1.0) * 100)
        .clamp(0, 100)
        .toDouble();
    return ScoreComponent(
      key: key,
      label: label,
      weight: weight,
      score: score,
      detail: '${_h(actual)} of ${_h(goal)} goal.',
    );
  }

  ScoreComponent _ratingComponent({
    required String key,
    required String label,
    required double weight,
    required double? rating,
  }) {
    if (rating == null) {
      return ScoreComponent(
        key: key,
        label: label,
        weight: weight,
        score: null,
        detail: 'Not rated.',
      );
    }
    final double score = rating.clamp(0, 100).toDouble();
    return ScoreComponent(
      key: key,
      label: label,
      weight: weight,
      score: score,
      detail: 'Self-rated ${score.round()}%.',
    );
  }

  ScoreComponent _activityComponent(DailyProductivityLog log) {
    if (log.activityScore != null) {
      return _ratingComponent(
        key: 'activity',
        label: 'Physical Activity',
        weight: activityWeight,
        rating: log.activityScore,
      );
    }
    final int? active = log.measuredActiveMinutes;
    if (active != null) {
      final double score = (min(active / activeMinutesGoal, 1.0) * 100)
          .toDouble();
      return ScoreComponent(
        key: 'activity',
        label: 'Physical Activity',
        weight: activityWeight,
        score: score,
        detail: '$active of $activeMinutesGoal active minutes (measured).',
      );
    }
    return const ScoreComponent(
      key: 'activity',
      label: 'Physical Activity',
      weight: activityWeight,
      score: null,
      detail: 'Not rated and no movement data.',
    );
  }

  ScoreComponent _lowDistractionComponent({
    required double? screenHours,
    required double? limitHours,
  }) {
    const String key = 'lowDistraction';
    const String label = 'Low Distraction';
    if (screenHours == null) {
      return const ScoreComponent(
        key: key,
        label: label,
        weight: lowDistractionWeight,
        score: null,
        detail: 'No screen time recorded.',
      );
    }
    if (limitHours == null) {
      return const ScoreComponent(
        key: key,
        label: label,
        weight: lowDistractionWeight,
        score: null,
        detail: 'No screen-time limit set in your profile.',
      );
    }
    final double excess = max(0, screenHours - limitHours);
    final double score = max(
      0,
      100 - excess * pointsLostPerHourOverLimit,
    ).toDouble();
    return ScoreComponent(
      key: key,
      label: label,
      weight: lowDistractionWeight,
      score: score,
      detail: excess == 0
          ? '${_h(screenHours)} screen time, within your ${_h(limitHours)} limit.'
          : '${_h(screenHours)} screen time, ${_h(excess)} over your limit.',
    );
  }

  String _feedback(double? score, List<ScoreComponent> components) {
    if (score == null) {
      return 'Record at least one metric to calculate a score.';
    }
    final ScoreComponent? weakest = _weakest(components);
    if (score >= 85) {
      return 'A strong, well-balanced day. Keep this routine going.';
    }
    if (weakest == null) {
      return 'Good progress today.';
    }
    return 'Your weakest area today was ${weakest.label.toLowerCase()} '
        '(${weakest.score!.round()}/100): ${weakest.detail}';
  }

  ScoreComponent? _weakest(List<ScoreComponent> components) {
    final List<ScoreComponent> available =
        components.where((ScoreComponent c) => c.isAvailable).toList()
          ..sort((a, b) => a.score!.compareTo(b.score!));
    return available.isEmpty ? null : available.first;
  }

  List<String> _suggestions(List<ScoreComponent> components) {
    final List<String> suggestions = <String>[];
    for (final ScoreComponent c in components) {
      final double? s = c.score;
      if (s == null) {
        if (c.detail.contains('goal') || c.detail.contains('limit')) {
          suggestions.add(
            'Set your ${c.label.toLowerCase()} goal in Goals so it can be scored.',
          );
        }
        continue;
      }
      if (s >= 70) {
        continue;
      }
      switch (c.key) {
        case 'focus':
          suggestions.add(
            'Schedule one 25-minute Focus Mode session before checking your phone.',
          );
          break;
        case 'sleep':
          suggestions.add(
            'Move your bedtime 30 minutes earlier to close the sleep gap.',
          );
          break;
        case 'consistency':
          suggestions.add(
            'Pick one fixed study slot for tomorrow and keep it.',
          );
          break;
        case 'activity':
          suggestions.add('Add a 15-minute walk; even short walks count.');
          break;
        case 'lowDistraction':
          suggestions.add(
            'Your screen time went over your limit; set app timers for your most distracting apps.',
          );
          break;
      }
    }
    return suggestions.take(3).toList();
  }

  String _h(double hours) {
    final int totalMinutes = (hours * 60).round();
    final int h = totalMinutes ~/ 60;
    final int m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}
