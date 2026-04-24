import 'package:cloud_firestore/cloud_firestore.dart';

class DailyProductivityLog {
  final DateTime date;
  final double actualSleepHours;
  final double actualStudyHours;
  final double actualFocusHours;
  final double actualScreenTimeHours;
  final double distractionLevel; // 0 to 1
  final double consistencyScore; // 0 to 100
  final double activityScore; // 0 to 100

  DailyProductivityLog({
    required this.date,
    this.actualSleepHours = 0,
    this.actualStudyHours = 0,
    this.actualFocusHours = 0,
    this.actualScreenTimeHours = 0,
    this.distractionLevel = 0,
    this.consistencyScore = 0,
    this.activityScore = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'actualSleepHours': actualSleepHours,
      'actualStudyHours': actualStudyHours,
      'actualFocusHours': actualFocusHours,
      'actualScreenTimeHours': actualScreenTimeHours,
      'distractionLevel': distractionLevel,
      'consistencyScore': consistencyScore,
      'activityScore': activityScore,
    };
  }

  factory DailyProductivityLog.fromMap(Map<String, dynamic> map) {
    return DailyProductivityLog(
      date: (map['date'] as Timestamp).toDate(),
      actualSleepHours: (map['actualSleepHours'] ?? 0).toDouble(),
      actualStudyHours: (map['actualStudyHours'] ?? 0).toDouble(),
      actualFocusHours: (map['actualFocusHours'] ?? 0).toDouble(),
      actualScreenTimeHours: (map['actualScreenTimeHours'] ?? 0).toDouble(),
      distractionLevel: (map['distractionLevel'] ?? 0).toDouble(),
      consistencyScore: (map['consistencyScore'] ?? 0).toDouble(),
      activityScore: (map['activityScore'] ?? 0).toDouble(),
    );
  }
}

class ProductivityScoreResult {
  final double overallScore;
  final double sleepScore;
  final double studyScore;
  final double focusScore;
  final double screenTimeScore;
  final double consistencyScore;
  final double activityScore;
  final String performanceLevel;
  final String feedbackMessage;
  final List<String> suggestions;

  ProductivityScoreResult({
    required this.overallScore,
    required this.sleepScore,
    required this.studyScore,
    required this.focusScore,
    required this.screenTimeScore,
    required this.consistencyScore,
    required this.activityScore,
    required this.performanceLevel,
    required this.feedbackMessage,
    required this.suggestions,
  });

  Map<String, dynamic> toMap() {
    return {
      'overallScore': overallScore,
      'sleepScore': sleepScore,
      'studyScore': studyScore,
      'focusScore': focusScore,
      'screenTimeScore': screenTimeScore,
      'consistencyScore': consistencyScore,
      'activityScore': activityScore,
      'performanceLevel': performanceLevel,
      'feedbackMessage': feedbackMessage,
      'suggestions': suggestions,
    };
  }

  factory ProductivityScoreResult.fromMap(Map<String, dynamic> map) {
    return ProductivityScoreResult(
      overallScore: (map['overallScore'] ?? 0).toDouble(),
      sleepScore: (map['sleepScore'] ?? 0).toDouble(),
      studyScore: (map['studyScore'] ?? 0).toDouble(),
      focusScore: (map['focusScore'] ?? 0).toDouble(),
      screenTimeScore: (map['screenTimeScore'] ?? 0).toDouble(),
      consistencyScore: (map['consistencyScore'] ?? 0).toDouble(),
      activityScore: (map['activityScore'] ?? 0).toDouble(),
      performanceLevel: map['performanceLevel'] ?? 'Medium',
      feedbackMessage: map['feedbackMessage'] ?? '',
      suggestions: List<String>.from(map['suggestions'] ?? []),
    );
  }
}
