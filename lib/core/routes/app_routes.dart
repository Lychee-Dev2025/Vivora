import 'package:flutter/material.dart';

import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/badges/presentation/badges_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/focus_mode/presentation/focus_mode_screen.dart';
import '../../features/productivity_scoring/presentation/screens/daily_productivity_entry_screen.dart';
import '../../features/goals/presentation/goals_screen.dart';
import '../../features/home/presentation/main_navigation_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/reports/presentation/report_detail_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/first_time_setup/presentation/first_time_setup_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import 'route_transitions.dart';

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String mainNavigation = '/mainNavigation';

  static const String dashboard = '/dashboard';
  static const String analytics = '/analytics';
  static const String reports = '/reports';
  static const String focusMode = '/focusMode';
  static const String goals = '/goals';
  static const String badges = '/badges';
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String editProfile = '/editProfile';
  static const String reportDetail = '/reportDetail';
  static const String firstTimeSetup = '/firstTimeSetup';
  static const String dailyProductivityEntry = '/dailyProductivityEntry';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case dailyProductivityEntry:
        return RouteTransitions.slide(
          page: const DailyProductivityEntryScreen(),
          settings: settings,
          begin: const Offset(0, 0.1),
        );
      case firstTimeSetup:
        return RouteTransitions.fade(
          page: const FirstTimeSetupScreen(),
          settings: settings,
        );
      case splash:
        return RouteTransitions.fade(
          page: const SplashScreen(),
          settings: settings,
        );
      case onboarding:
        return RouteTransitions.slide(
          page: const OnboardingScreen(),
          settings: settings,
        );
      case auth:
        return RouteTransitions.slide(
          page: const AuthScreen(),
          settings: settings,
          begin: const Offset(0, 0.08),
        );
      case mainNavigation:
        return RouteTransitions.fade(
          page: const MainNavigationScreen(),
          settings: settings,
        );
      case dashboard:
        return RouteTransitions.slide(
          page: const DashboardScreen(showAppBar: true),
          settings: settings,
        );
      case analytics:
        return RouteTransitions.slide(
          page: const AnalyticsScreen(showAppBar: true),
          settings: settings,
        );
      case reports:
        return RouteTransitions.slide(
          page: const ReportsScreen(showAppBar: true),
          settings: settings,
        );
      case focusMode:
        return RouteTransitions.slide(
          page: const FocusModeScreen(),
          settings: settings,
        );
      case goals:
        return RouteTransitions.slide(
          page: const GoalsScreen(),
          settings: settings,
        );
      case badges:
        return RouteTransitions.slide(
          page: const BadgesScreen(),
          settings: settings,
        );
      case AppRoutes.settings:
        return RouteTransitions.slide(
          page: const SettingsScreen(),
          settings: settings,
          begin: const Offset(0, 0.1),
        );
      case profile:
        return RouteTransitions.slide(
          page: const ProfileScreen(showAppBar: true),
          settings: settings,
        );
      case editProfile:
        return RouteTransitions.slide(
          page: const EditProfileScreen(),
          settings: settings,
          begin: const Offset(0, 0.1),
        );
      case reportDetail:
        final String title = settings.arguments is String
            ? settings.arguments! as String
            : 'Report';
        return RouteTransitions.slide(
          page: ReportDetailScreen(title: title),
          settings: settings,
          begin: const Offset(0, 0.12),
        );
      default:
        return RouteTransitions.fade(
          page: const SplashScreen(),
          settings: settings,
        );
    }
  }
}
