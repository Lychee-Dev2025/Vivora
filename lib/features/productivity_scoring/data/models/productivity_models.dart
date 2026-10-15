import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../activity_monitoring/data/models/activity_date_utils.dart';

/// One day of user-supplied (and device-prefilled) productivity inputs.
///
/// Every metric is nullable: `null` means "not recorded", which the scoring
/// treats as missing data rather than as zero.
class DailyProductivityLog {
  DailyProductivityLog({
    required DateTime date,
    this.actualSleepHours,
    this.actualStudyHours,
    this.actualFocusHours,
    this.actualScreenTimeHours,
    this.screenTimeFromDevice = false,
    this.consistencyScore,
    this.activityScore,
    this.measuredActiveMinutes,
    this.focusSessionMinutes,
  }) : date = ActivityDateUtils.dayStart(date);

  /// Local midnight of the logged day.
  final DateTime date;
  final double? actualSleepHours;
  final double? actualStudyHours;
  final double? actualFocusHours;
  final double? actualScreenTimeHours;

  /// True when [actualScreenTimeHours] came from Android app usage unchanged.
  final bool screenTimeFromDevice;

  /// Self-rated adherence to the planned routine, 0-100.
  final double? consistencyScore;

  /// Self-rated physical activity, 0-100.
  final double? activityScore;

  /// Walking + running minutes measured by activity recognition, if available.
  final int? measuredActiveMinutes;

  /// Minutes of focus sessions completed in Focus Mode that day.
  final int? focusSessionMinutes;

  String get dayKey => ActivityDateUtils.dayKey(date);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'date': Timestamp.fromDate(date),
      'dateKey': dayKey,
      'actualSleepHours': actualSleepHours,
      'actualStudyHours': actualStudyHours,
      'actualFocusHours': actualFocusHours,
      'actualScreenTimeHours': actualScreenTimeHours,
      'screenTimeFromDevice': screenTimeFromDevice,
      'consistencyScore': consistencyScore,
      'activityScore': activityScore,
      'measuredActiveMinutes': measuredActiveMinutes,
      'focusSessionMinutes': focusSessionMinutes,
    };
  }

  factory DailyProductivityLog.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final DateTime date =
        ActivityDateUtils.parseKey(documentId) ??
        ActivityDateUtils.parseKey(map['dateKey']?.toString()) ??
        _asDate(map['date']) ??
        DateTime.now();
    return DailyProductivityLog(
      date: date,
      actualSleepHours: _asDouble(map['actualSleepHours']),
      actualStudyHours: _asDouble(map['actualStudyHours']),
      actualFocusHours: _asDouble(map['actualFocusHours']),
      actualScreenTimeHours: _asDouble(map['actualScreenTimeHours']),
      screenTimeFromDevice: map['screenTimeFromDevice'] == true,
      consistencyScore: _asDouble(map['consistencyScore']),
      activityScore: _asDouble(map['activityScore']),
      measuredActiveMinutes: _asDouble(map['measuredActiveMinutes'])?.round(),
      focusSessionMinutes: _asDouble(map['focusSessionMinutes'])?.round(),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return value == null ? null : double.tryParse(value.toString());
  }

  static DateTime? _asDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}

/// One weighted part of the overall score.
class ScoreComponent {
  const ScoreComponent({
    required this.key,
    required this.label,
    required this.weight,
    required this.score,
    required this.detail,
  });

  final String key;
  final String label;

  /// Fraction of the overall score, e.g. 0.30.
  final double weight;

  /// 0-100, or null when the input or goal needed for it is missing.
  final double? score;

  /// Why the score is what it is (or why it is missing).
  final String detail;

  bool get isAvailable => score != null;
}

class ProductivityScoreResult {
  ProductivityScoreResult({
    required this.overallScore,
    required this.components,
    required this.performanceLevel,
    required this.feedbackMessage,
    required this.suggestions,
  });

  /// 0-100 over the available components, or null when none is available.
  final double? overallScore;
  final List<ScoreComponent> components;
  final String performanceLevel;
  final String feedbackMessage;
  final List<String> suggestions;

  /// Sum of the weights that contributed (1.0 = every component recorded).
  double get coverage => components
      .where((ScoreComponent c) => c.isAvailable)
      .fold<double>(0, (double sum, ScoreComponent c) => sum + c.weight);

  bool get isPartial => coverage < 0.999;

  List<String> get missingComponents => components
      .where((ScoreComponent c) => !c.isAvailable)
      .map((ScoreComponent c) => c.label)
      .toList();

  double? componentScore(String key) {
    for (final ScoreComponent component in components) {
      if (component.key == key) {
        return component.score;
      }
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'overallScore': overallScore,
      'focusScore': componentScore('focus'),
      'sleepScore': componentScore('sleep'),
      'consistencyComponentScore': componentScore('consistency'),
      'activityComponentScore': componentScore('activity'),
      'lowDistractionScore': componentScore('lowDistraction'),
      // Legacy name of the low-distraction component.
      'screenTimeScore': componentScore('lowDistraction'),
      'scoreCoverage': coverage,
      'missingComponents': missingComponents,
      'performanceLevel': performanceLevel,
      'feedbackMessage': feedbackMessage,
      'suggestions': suggestions,
      'scoringVersion': 2,
    };
  }
}

/// A saved daily log together with its score, as read back from Firestore.
class SavedDailyScore {
  const SavedDailyScore({
    required this.log,
    required this.overallScore,
    required this.performanceLevel,
    required this.feedbackMessage,
    required this.suggestions,
    required this.coverage,
    required this.missingComponents,
    required this.componentScores,
  });

  final DailyProductivityLog log;
  final double? overallScore;
  final String? performanceLevel;
  final String? feedbackMessage;
  final List<String> suggestions;

  /// Null for logs saved before coverage was recorded.
  final double? coverage;
  final List<String> missingComponents;
  final Map<String, double?> componentScores;

  DateTime get date => log.date;

  factory SavedDailyScore.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    double? asDouble(dynamic value) => value is num ? value.toDouble() : null;
    return SavedDailyScore(
      log: DailyProductivityLog.fromMap(map, documentId: documentId),
      overallScore: asDouble(map['overallScore']),
      performanceLevel: map['performanceLevel']?.toString(),
      feedbackMessage: map['feedbackMessage']?.toString(),
      suggestions: List<String>.from(
        (map['suggestions'] as List<dynamic>?) ?? const <dynamic>[],
      ),
      coverage: asDouble(map['scoreCoverage']),
      missingComponents: List<String>.from(
        (map['missingComponents'] as List<dynamic>?) ?? const <dynamic>[],
      ),
      componentScores: <String, double?>{
        'focus': asDouble(map['focusScore']),
        'sleep': asDouble(map['sleepScore']),
        'consistency':
            asDouble(map['consistencyComponentScore']) ??
            asDouble(map['consistencyScore']),
        'activity':
            asDouble(map['activityComponentScore']) ??
            asDouble(map['activityScore']),
        'lowDistraction':
            asDouble(map['lowDistractionScore']) ??
            asDouble(map['screenTimeScore']),
      },
    );
  }
}
