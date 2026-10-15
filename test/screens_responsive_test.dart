import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivora/core/services/session.dart';
import 'package:vivora/features/activity_monitoring/data/models/activity_sync_snapshot.dart';
import 'package:vivora/features/activity_monitoring/data/services/activity_sync_service.dart';
import 'package:vivora/features/activity_monitoring/presentation/widgets/tracking_status_card.dart';
import 'package:vivora/features/analytics/presentation/analytics_screen.dart';
import 'package:vivora/features/auth/presentation/auth_screen.dart';
import 'package:vivora/features/badges/data/badge_service.dart';
import 'package:vivora/features/badges/presentation/badges_screen.dart';
import 'package:vivora/features/dashboard/presentation/dashboard_screen.dart';
import 'package:vivora/features/first_time_setup/presentation/first_time_setup_screen.dart';
import 'package:vivora/features/first_time_setup/presentation/widgets/goals_step.dart';
import 'package:vivora/features/first_time_setup/presentation/widgets/personal_info_step.dart';
import 'package:vivora/features/first_time_setup/presentation/widgets/preferences_step.dart';
import 'package:vivora/features/first_time_setup/presentation/widgets/routine_profile_step.dart';
import 'package:vivora/features/first_time_setup/presentation/widgets/setup_summary_step.dart';
import 'package:vivora/features/focus_mode/presentation/focus_mode_screen.dart';
import 'package:vivora/features/goals/presentation/goals_screen.dart';
import 'package:vivora/features/home/presentation/main_navigation_screen.dart';
import 'package:vivora/features/insights/services/insights_service.dart';
import 'package:vivora/features/onboarding/presentation/onboarding_screen.dart';
import 'package:vivora/features/productivity_scoring/data/services/productivity_score_service.dart';
import 'package:vivora/features/productivity_scoring/presentation/screens/daily_productivity_entry_screen.dart';
import 'package:vivora/features/profile/presentation/edit_profile_screen.dart';
import 'package:vivora/features/profile/presentation/profile_screen.dart';
import 'package:vivora/features/reports/presentation/report_detail_screen.dart';
import 'package:vivora/features/reports/presentation/reports_screen.dart';
import 'package:vivora/features/settings/presentation/settings_screen.dart';
import 'package:vivora/features/splash/presentation/splash_screen.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/layout_harness.dart';

Future<ActivitySyncService> syncedService({bool usageAccess = true}) async {
  final FakeDataSource device =
      FakeDataSource(apps: fixtureApps, appUsageMinutes: 1442)
        ..permissions = ActivityPermissionSnapshot(
          usageAccessGranted: usageAccess,
          activityPermissionGranted: usageAccess,
          notificationPermissionGranted: true,
          backgroundSyncEnabled: false,
        );
  final ActivitySyncService service = ActivitySyncService(
    dataSource: device,
    repository: FakeActivityRepository(),
    currentUserId: () => 'test-user',
  );
  await service.syncNow(force: true);
  return service;
}

void main() {
  setUp(() {
    // No Firebase in widget tests: screens see "signed out".
    Session.currentUserId = () => null;
    Session.currentEmail = () => null;
  });

  group('Badges', () {
    final Map<String, DateTime> all = <String, DateTime>{
      for (final BadgeDefinition b in BadgeService.all) b.id: fixtureNow,
    };
    testWidgets(
      'loading',
      (t) => expectResponsive(t, () => const BadgesView(unlocked: null)),
    );
    testWidgets(
      'all locked',
      (t) => expectResponsive(
        t,
        () => const BadgesView(unlocked: <String, DateTime>{}),
      ),
    );
    testWidgets(
      'all unlocked with dates',
      (t) => expectResponsive(t, () => BadgesView(unlocked: all)),
    );
    testWidgets(
      'mixed, with error message',
      (t) => expectResponsive(
        t,
        () => BadgesView(
          unlocked: <String, DateTime>{
            'first_log': fixtureNow,
            'focus_king': fixtureNow,
          },
          error:
              'Could not load badges: [cloud_firestore/unavailable] The service is currently unavailable.',
        ),
      ),
    );
  });

  group('Home dashboard', () {
    testWidgets('empty (new user, no data)', (t) async {
      final service = ActivitySyncService(
        dataSource: FakeDataSource(),
        repository: FakeActivityRepository(),
        currentUserId: () => null,
      );
      await expectResponsive(
        t,
        () => DashboardView(
          userName: '',
          snapshot: fixtureSnapshot(empty: true),
          today: null,
          activityService: service,
        ),
      );
    });
    testWidgets('populated with large values', (t) async {
      final service = await syncedService();
      await expectResponsive(
        t,
        () => DashboardView(
          userName: 'Muhammadumarabdullah',
          snapshot: fixtureSnapshot(),
          today: fixtureToday(),
          activityService: service,
        ),
      );
    });
    testWidgets('usage access not granted', (t) async {
      final service = await syncedService(usageAccess: false);
      await expectResponsive(
        t,
        () => DashboardView(
          userName: 'Umar',
          snapshot: null,
          today: null,
          loading: true,
          activityService: service,
        ),
      );
    });
  });

  group('Analytics', () {
    testWidgets(
      'loading',
      (t) => expectResponsive(
        t,
        () => const AnalyticsView(snapshot: null, today: null),
      ),
    );
    testWidgets(
      'no data',
      (t) => expectResponsive(
        t,
        () => AnalyticsView(
          snapshot: fixtureSnapshot(empty: true),
          today: null,
          now: fixtureNow,
        ),
      ),
    );
    testWidgets(
      'populated',
      (t) => expectResponsive(
        t,
        () => AnalyticsView(
          snapshot: fixtureSnapshot(),
          today: fixtureToday(),
          now: fixtureNow,
        ),
      ),
    );
    testWidgets(
      'category bottom sheet',
      (t) => expectResponsive(
        t,
        () => AnalyticsView(
          snapshot: fixtureSnapshot(),
          today: fixtureToday(),
          now: fixtureNow,
        ),
        heights: const <double>[640],
        interact: (tester) async {
          await tester.ensureVisible(find.text('WhatsApp').last);
          await tester.pump();
          await tester.tap(find.text('WhatsApp').last);
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            find.text(
              'Applies to all days. "Uncategorized" restores the default.',
            ),
            findsOneWidget,
          );
        },
      ),
    );
  });

  group('Reports', () {
    testWidgets(
      'loading',
      (t) => expectResponsive(
        t,
        () => const ReportsView(scores: [], activity: [], loading: true),
      ),
    );
    testWidgets(
      'empty with error',
      (t) => expectResponsive(
        t,
        () => const ReportsView(
          scores: [],
          activity: [],
          error:
              'Could not load reports: TimeoutException after 0:00:10.000000: Future not completed',
        ),
      ),
    );
    testWidgets(
      'populated',
      (t) => expectResponsive(
        t,
        () => ReportsView(
          scores: fixtureHistory().scores,
          activity: fixtureHistory().activityLogs,
          now: fixtureNow,
        ),
      ),
    );
  });

  group('Daily report detail', () {
    testWidgets(
      'full report with long app names',
      (t) => expectResponsive(
        t,
        () => ReportDetailView(
          dayKey: '2026-10-15',
          score: fixtureScore(0, 78, partial: true),
          activity: fixtureActivity(0, 1442),
          apps: fixtureApps,
        ),
      ),
    );
    testWidgets(
      'no records',
      (t) => expectResponsive(
        t,
        () => const ReportDetailView(
          dayKey: '2026-10-15',
          score: null,
          activity: null,
        ),
      ),
    );
  });

  group('Goals', () {
    testWidgets(
      'loading',
      (t) => expectResponsive(
        t,
        () => const GoalsView(
          goals: null,
          appUsageMinutes: null,
          todayLog: null,
          loading: true,
        ),
      ),
    );
    testWidgets(
      'no goals set',
      (t) => expectResponsive(
        t,
        () =>
            const GoalsView(goals: null, appUsageMinutes: null, todayLog: null),
      ),
    );
    testWidgets(
      'over limit with logged values',
      (t) => expectResponsive(
        t,
        () => GoalsView(
          goals: fixtureGoals,
          appUsageMinutes: 1442,
          todayLog: fixtureScore(0, 78).log,
          error: 'Could not load your goals: offline',
        ),
      ),
    );
    testWidgets(
      'edit dialog',
      (t) => expectResponsive(
        t,
        () => Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showGoalHoursDialog(
                context,
                title: 'Edit Screen Time Limit',
                initialHours: 3,
                maxHours: 12,
              );
            });
            return const Scaffold();
          },
        ),
        heights: const <double>[640],
      ),
    );
  });

  group('Profile and settings', () {
    testWidgets(
      'profile with long details',
      (t) => expectResponsive(
        t,
        () => ProfileView(
          profile: fixtureProfile(),
          insights: ValueNotifier<InsightsSnapshot?>(fixtureSnapshot()),
          showAppBar: true,
        ),
      ),
    );
    testWidgets(
      'profile not loaded',
      (t) => expectResponsive(
        t,
        () => ProfileView(
          profile: null,
          insights: ValueNotifier<InsightsSnapshot?>(null),
        ),
      ),
    );
    testWidgets(
      'edit profile: signed out (error state)',
      (t) => expectResponsive(t, () => const EditProfileScreen()),
    );
    testWidgets('edit profile: filled form', (t) async {
      Session.currentUserId = () => 'test-user';
      await expectResponsive(
        t,
        () => EditProfileScreen(
          loadProfile: (_) async => fixtureProfile(),
          saveProfile: (_) async {},
        ),
      );
    });
    testWidgets(
      'settings screen',
      (t) => expectResponsive(t, () => const SettingsScreen()),
    );
    testWidgets(
      'measurement info dialog',
      (t) => expectResponsive(
        t,
        () => Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              SettingsScreen.showMeasurementInfo(context);
            });
            return const Scaffold();
          },
        ),
        heights: const <double>[640],
      ),
    );
  });

  group('Logging, focus and tracking', () {
    testWidgets(
      'daily progress form with every metric recorded',
      (t) => expectResponsive(
        t,
        () => const DailyProductivityEntryScreen(),
        interact: (tester) async {
          while (find.text('Record').evaluate().isNotEmpty) {
            await tester.ensureVisible(find.text('Record').first);
            await tester.tap(find.text('Record').first);
            await tester.pump();
          }
        },
      ),
    );
    testWidgets(
      'score preview',
      (t) => expectResponsive(
        t,
        () => Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ScorePreviewCard(
              result: ProductivityScoreService().calculate(
                log: fixtureScore(0, 78, partial: true).log,
                goals: fixtureGoals,
              ),
            ),
          ),
        ),
      ),
    );
    testWidgets(
      'focus mode',
      (t) => expectResponsive(t, () => const FocusModeScreen()),
    );
    testWidgets('tracking card: permission required', (t) async {
      final service = await syncedService(usageAccess: false);
      await expectResponsive(
        t,
        () => Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [TrackingStatusCard(service: service)],
          ),
        ),
      );
    });
  });

  group('Entry flow', () {
    testWidgets(
      'splash',
      (t) => expectResponsive(
        t,
        () => const SplashScreen(),
        heights: const <double>[640, 900],
        // Before the 3 s splash timer navigates onwards (into Firebase).
        settle: const Duration(milliseconds: 2500),
      ),
    );
    testWidgets(
      'onboarding',
      (t) => expectResponsive(
        t,
        () => const OnboardingScreen(),
        heights: const <double>[640, 900],
      ),
    );
    testWidgets(
      'login form',
      (t) => expectResponsive(
        t,
        () => const AuthScreen(),
        heights: const <double>[640, 900],
      ),
    );
    testWidgets(
      'sign-up form',
      (t) => expectResponsive(
        t,
        () => const AuthScreen(),
        heights: const <double>[640, 900],
        interact: (tester) async {
          await tester.ensureVisible(find.text('Sign Up').first);
          await tester.pump();
          await tester.tap(find.text('Sign Up').first);
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('Confirm Password'), findsOneWidget);
        },
      ),
    );
    testWidgets(
      'first-time setup',
      (t) => expectResponsive(
        t,
        () => const FirstTimeSetupScreen(),
        heights: const <double>[640, 900],
      ),
    );
    for (final MapEntry<String, Widget Function()> step
        in <String, Widget Function()>{
          'personal info': () =>
              Scaffold(body: PersonalInfoStep(onContinue: (a, b, c, d, e) {})),
          'routine': () => Scaffold(
            body: RoutineProfileStep(onContinue: (a, b, c, d, e, f) {}),
          ),
          'goals': () =>
              Scaffold(body: GoalsStep(onContinue: (a, b, c, d, e) {})),
          'preferences': () =>
              Scaffold(body: PreferencesStep(onContinue: (a, b, c, d) {})),
          'summary': () => Scaffold(
            body: SetupSummaryStep(
              fullName: 'Muhammad Umar Abdullah Rahman Siddiqui',
              academicLevel: 'Undergraduate (Final Year Project)',
              mainChallenge: 'Procrastination and social media distractions',
              productivityGoal: 'Improve focus and reduce distractions',
              isLoading: false,
              onEdit: (_) {},
              onFinish: () {},
            ),
          ),
        }.entries) {
      testWidgets(
        'setup step: ${step.key}',
        (t) =>
            expectResponsive(t, step.value, heights: const <double>[640, 900]),
      );
    }
    testWidgets(
      'bottom navigation labels',
      (t) => expectResponsive(
        t,
        () => const MainNavigationScreen(
          tabs: <Widget>[SizedBox(), SizedBox(), SizedBox(), SizedBox()],
        ),
        heights: const <double>[640],
      ),
    );
  });
}
