import 'dart:math';
import '../../../first_time_setup/data/models/user_profile_model.dart';
import '../models/productivity_models.dart';

class ProductivityScoreService {
  ProductivityScoreResult calculateScore({
    required DailyProductivityLog log,
    required UserProfile profile,
  }) {
    // 1. Normalize Category Scores (0-100)
    
    // Sleep Score (20% weight)
    double sleepScore = _calculateCategoryScore(
      actual: log.actualSleepHours,
      target: _parseHours(profile.goals.targetSleepHours),
      isPenalty: false,
    );

    // Study Score (Part of focus usually, but let's calculate it)
    double studyScore = _calculateCategoryScore(
      actual: log.actualStudyHours,
      target: _parseHours(profile.goals.targetStudyHours),
      isPenalty: false,
    );

    // Focus Score (30% weight)
    double focusScore = _calculateCategoryScore(
      actual: log.actualFocusHours,
      target: _parseHours(profile.goals.targetFocusHours),
      isPenalty: false,
    );

    // Screen Time Score (15% weight)
    double screenTimeScore = _calculateCategoryScore(
      actual: log.actualScreenTimeHours,
      target: _parseHours(profile.goals.targetScreenTimeLimit),
      isPenalty: true, // Over target is bad
    );

    // Activity Score (15% weight)
    double activityScore = log.activityScore;

    // Consistency Score (20% weight)
    double consistencyScore = log.consistencyScore;

    // 2. Apply Weights
    // Weights: Focus(30), Sleep(20), Activity(15), Consistency(20), Screen Discipline(15)
    double overallScore = (focusScore * 0.30) +
        (sleepScore * 0.20) +
        (activityScore * 0.15) +
        (consistencyScore * 0.20) +
        (screenTimeScore * 0.15);

    overallScore = overallScore.clamp(0, 100);

    // 3. Performance Level
    String performanceLevel = _getClassification(overallScore);

    // 4. Feedback & Suggestions
    String feedbackMessage = _getFeedback(overallScore, performanceLevel);
    List<String> suggestions = _getSuggestions(
      sleepScore: sleepScore,
      focusScore: focusScore,
      screenScore: screenTimeScore,
      overallScore: overallScore,
    );

    return ProductivityScoreResult(
      overallScore: overallScore,
      sleepScore: sleepScore,
      studyScore: studyScore,
      focusScore: focusScore,
      screenTimeScore: screenTimeScore,
      consistencyScore: consistencyScore,
      activityScore: activityScore,
      performanceLevel: performanceLevel,
      feedbackMessage: feedbackMessage,
      suggestions: suggestions,
    );
  }

  double _calculateCategoryScore({
    required double actual,
    required double target,
    required bool isPenalty,
  }) {
    if (target <= 0) return 100; // If no goal, give full score or ignore

    if (isPenalty) {
      // For screen time: being at or below target is 100. Being above reduces score.
      if (actual <= target) return 100;
      double excess = actual - target;
      return max(0, 100 - (excess * 20)); // Lose 20 points per hour over
    } else {
      // For focus/sleep: reaching target is 100.
      if (actual >= target) return 100;
      return (actual / target) * 100;
    }
  }

  String _getClassification(double score) {
    if (score >= 85) return 'Excellent';
    if (score >= 70) return 'Good';
    if (score >= 50) return 'Medium';
    return 'Needs Improvement';
  }

  String _getFeedback(double score, String level) {
    if (score >= 85) {
      return "You had a strong and focused day. Keep this consistency going!";
    } else if (score >= 70) {
      return "Your progress is good, but reducing screen time can improve your performance.";
    } else if (score >= 50) {
      return "You're doing okay, but there's room to reach your daily goals.";
    } else {
      return "Your sleep and focus were below target today. Try adjusting your routine tomorrow.";
    }
  }

  List<String> _getSuggestions({
    required double sleepScore,
    required double focusScore,
    required double screenScore,
    required double overallScore,
  }) {
    List<String> suggestions = [];
    if (sleepScore < 70) suggestions.add("Try to get to bed 30 mins earlier.");
    if (focusScore < 70) suggestions.add("Use Pomodoro sessions to boost focus.");
    if (screenScore < 70) suggestions.add("Set app limits for distracting apps.");
    
    if (suggestions.isEmpty && overallScore < 90) {
      suggestions.add("Keep pushing to exceed your current targets!");
    } else if (suggestions.isEmpty) {
      suggestions.add("Excellent job! Maintain this peak performance.");
    }
    
    return suggestions.take(3).toList();
  }

  double _parseHours(String hoursStr) {
    // Extracts number from strings like "8h", "6 hours", etc.
    final regExp = RegExp(r'(\d+)');
    final match = regExp.firstMatch(hoursStr);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }
}
