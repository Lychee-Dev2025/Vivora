import 'package:vivora/features/activity_monitoring/data/models/activity_date_utils.dart';
import 'package:vivora/features/activity_monitoring/data/models/activity_sync_snapshot.dart';
import 'package:vivora/features/activity_monitoring/data/models/app_usage_entry.dart';
import 'package:vivora/features/activity_monitoring/data/models/daily_activity_log.dart';
import 'package:vivora/features/first_time_setup/data/models/user_profile_model.dart';
import 'package:vivora/features/focus_mode/data/focus_session_repository.dart';
import 'package:vivora/features/insights/data/history_data.dart';
import 'package:vivora/features/behavior_analysis/domain/behavior_analysis_engine.dart';
import 'package:vivora/features/behavior_analysis/domain/behavior_models.dart';
import 'package:vivora/features/insights/services/insights_service.dart';
import 'package:vivora/features/insights/services/recommendation_service.dart';
import 'package:vivora/features/productivity_scoring/data/models/productivity_models.dart';

import 'fakes.dart';

/// Synthetic, test-only data shaped like a real week of Vivora use, with
/// deliberately long names and large values to stress layouts.
final DateTime fixtureNow = DateTime(2026, 10, 15, 16, 30);

DateTime fixtureDay(int daysAgo) =>
    DateTime(fixtureNow.year, fixtureNow.month, fixtureNow.day - daysAgo);

final UserGoals fixtureGoals = UserGoals(
  targetSleepHours: '8h',
  targetStudyHours: '4h',
  targetFocusHours: '4h',
  targetScreenTimeLimit: '3h',
  productivityGoalType: 'Improve focus and reduce distractions',
);

SavedDailyScore fixtureScore(
  int daysAgo,
  double score, {
  bool partial = false,
}) {
  return SavedDailyScore(
    log: DailyProductivityLog(
      date: fixtureDay(daysAgo),
      actualSleepHours: 7.5,
      actualStudyHours: 3,
      actualFocusHours: 2,
      actualScreenTimeHours: partial ? null : 4.25,
      consistencyScore: partial ? null : 80,
      activityScore: 60,
      screenTimeFromDevice: true,
    ),
    overallScore: score,
    performanceLevel: score >= 85
        ? 'Excellent'
        : score >= 70
        ? 'Good'
        : score >= 50
        ? 'Medium'
        : 'Needs Improvement',
    feedbackMessage:
        'Your weakest area today was focus (50/100): 2h of 4h goal.',
    suggestions: const <String>[
      'Schedule one 25-minute Focus Mode session before checking your phone.',
      'Your screen time went over your limit; set app timers for your most distracting apps.',
    ],
    coverage: partial ? 0.65 : 1,
    missingComponents: partial
        ? const <String>['Consistency', 'Low Distraction']
        : const <String>[],
    componentScores: <String, double?>{
      'focus': 50,
      'sleep': 94,
      'consistency': partial ? null : 80,
      'activity': 60,
      'lowDistraction': partial ? null : 75,
    },
  );
}

final List<AppUsageEntry> fixtureApps = <AppUsageEntry>[
  app(
    'com.whatsapp',
    'WhatsApp',
    const Duration(minutes: 13),
    category: AppCategory.neutral,
  ),
  app(
    'com.google.android.youtube',
    'YouTube',
    const Duration(hours: 2, minutes: 47),
    category: AppCategory.distracting,
  ),
  app(
    'com.example.vivora',
    'vivora',
    const Duration(minutes: 7),
    category: AppCategory.neutral,
  ),
  app(
    'com.miui.gallery',
    'Gallery',
    const Duration(minutes: 2),
    category: AppCategory.neutral,
  ),
  app('com.miui.securitycenter', 'Security', const Duration(seconds: 20)),
  app(
    'com.example.longname',
    'Microsoft Office Mobile Productivity Suite for Students',
    const Duration(minutes: 41),
    category: AppCategory.productive,
  ),
];

DailyActivityLog fixtureActivity(int daysAgo, int minutes) => DailyActivityLog(
  date: fixtureDay(daysAgo),
  appUsageMinutes: minutes,
  screenTimeMinutes: minutes + 25,
  phoneUnlockCount: 1234,
  productiveAppMinutes: 41,
  distractingAppMinutes: 167,
  neutralAppMinutes: 22,
  movementStatus: 'available',
  walkingMinutes: 35,
  runningMinutes: 0,
  lastSyncAt: fixtureNow,
  captureId: 'c$daysAgo',
);

TodayActivity fixtureToday() =>
    TodayActivity(log: fixtureActivity(0, 1442), apps: fixtureApps);

HistoryData fixtureHistory({bool empty = false}) {
  if (empty) return HistoryData.empty(fixtureNow);
  return HistoryData(
    today: fixtureNow,
    activityLogs: <DailyActivityLog>[
      for (int d = 6; d >= 0; d--) fixtureActivity(d, 120 + d * 37),
    ],
    appUsageByDay: <String, List<AppUsageEntry>>{
      for (int d = 6; d >= 0; d--)
        ActivityDateUtils.dayKey(fixtureDay(d)): fixtureApps,
    },
    scores: <SavedDailyScore>[
      fixtureScore(6, 64),
      fixtureScore(5, 80),
      fixtureScore(3, 100),
      fixtureScore(1, 80),
      fixtureScore(0, 78, partial: true),
    ],
    focusSessions: <FocusSession>[
      for (int d = 0; d < 5; d++)
        FocusSession(
          startedAt: fixtureDay(d).add(const Duration(hours: 10)),
          endedAt: fixtureDay(d).add(const Duration(hours: 10, minutes: 25)),
          plannedMinutes: 25,
          focusedSeconds: 1500,
          completed: true,
        ),
    ],
    goals: fixtureGoals,
  );
}

InsightsSnapshot fixtureSnapshot({bool empty = false}) {
  final HistoryData history = fixtureHistory(empty: empty);
  final Map<AnalysisPeriod, BehaviorAnalysis> analyses =
      const BehaviorAnalysisEngine().analyzeAll(history);
  return InsightsSnapshot(
    history: history,
    analyses: analyses,
    recommendations: const RecommendationService().generate(
      history: history,
      analysis: analyses[AnalysisPeriod.week]!,
    ),
  );
}

UserProfile fixtureProfile() => UserProfile(
  uid: 'test-user',
  email: 'a.very.long.student.email.address@university-example.edu.pk',
  fullName: 'Muhammad Umar Abdullah Rahman Siddiqui',
  ageRange: '18-24',
  academicLevel: 'Undergraduate (Final Year Project)',
  institution: 'National University of Sciences and Technology Islamabad',
  fieldOfStudy: 'Software Engineering',
  routineProfile: RoutineProfile(wakeUpTime: '7:00 AM', sleepTime: '11:30 PM'),
  goals: fixtureGoals,
  preferences: UserPreferences(),
  setupCompleted: true,
);
