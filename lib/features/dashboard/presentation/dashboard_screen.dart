import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import 'package:vivora/core/widgets/app_bar_title.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/chart_container.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/quick_action_tile.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../../activity_monitoring/data/models/activity_sync_snapshot.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../../activity_monitoring/data/services/activity_sync_service.dart';
import '../../activity_monitoring/presentation/widgets/tracking_status_card.dart';
import '../../analytics/data/analytics_calculator.dart';
import '../../analytics/presentation/widgets/productivity_charts.dart';
import '../../first_time_setup/data/services/user_profile_service.dart';
import '../../insights/presentation/insight_widgets.dart';
import '../../insights/services/insights_service.dart';
import '../../productivity_scoring/data/models/productivity_models.dart';
import 'widgets/greeting_header.dart';
import 'widgets/productivity_score_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _profileService = UserProfileService();
  final _activityService = ActivitySyncService.instance;
  final _insights = InsightsService.instance;

  String _userName = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData({bool forceSync = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    unawaited(_loadName(user));
    await Future.wait<Object?>(<Future<Object?>>[
      forceSync
          ? _activityService.syncNow(force: true)
          : _activityService.syncIfNeeded(),
      forceSync ? _insights.reload() : _insights.ensureLoaded(),
    ]);
  }

  Future<void> _loadName(User user) async {
    String name = user.displayName ?? '';
    try {
      final profile = await _profileService
          .getUserProfile(user.uid)
          .timeout(const Duration(seconds: 6));
      if (profile != null && profile.fullName.trim().isNotEmpty) {
        name = profile.fullName;
      }
    } catch (error) {
      debugPrint('Profile name unavailable: $error');
    }
    if (mounted) {
      setState(() => _userName = name.trim().split(' ').first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _insights.snapshot,
        _insights.loading,
        _activityService.today,
      ]),
      builder: (context, _) => DashboardView(
        showAppBar: widget.showAppBar,
        userName: _userName,
        snapshot: _insights.snapshot.value,
        today: _activityService.today.value,
        loading: _insights.loading.value,
        activityService: _activityService,
        onRefresh: () => _loadData(forceSync: true),
        onScoreSaved: () => unawaited(_insights.reload()),
      ),
    );
  }
}

/// The Home dashboard layout, driven entirely by its parameters.
class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.userName,
    required this.snapshot,
    required this.today,
    required this.activityService,
    this.loading = false,
    this.showAppBar = false,
    this.onRefresh,
    this.onScoreSaved,
  });

  final String userName;
  final InsightsSnapshot? snapshot;
  final TodayActivity? today;
  final ActivitySyncService activityService;
  final bool loading;
  final bool showAppBar;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onScoreSaved;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar ? AppBar(title: const AppBarTitle('Dashboard')) : null,
      body: GradientBackground(
        child: RefreshIndicator(
          onRefresh: onRefresh ?? () async {},
          color: context.brand,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final InsightsSnapshot? snapshot = this.snapshot;
    final TodayActivity? today = this.today;
    final SavedDailyScore? todayScore = snapshot?.history.todayScore;
    final DailyProductivityLog? todayLog = todayScore?.log;
    final SavedDailyScore? lastScore =
        snapshot == null || snapshot.history.scores.isEmpty
        ? null
        : snapshot.history.scores.last;

    final String scoreText = todayScore?.overallScore == null
        ? '--'
        : todayScore!.overallScore!.round().toString();
    final String feedback = todayScore != null
        ? (todayScore.feedbackMessage ?? '')
        : lastScore != null && lastScore.overallScore != null
        ? 'No score for today yet. Last score: ${lastScore.overallScore!.round()} on ${AnalyticsCalculator.formatDate(lastScore.date)}.'
        : 'Log your progress to see your productivity score.';

    final int? focusMinutes = todayLog?.actualFocusHours != null
        ? (todayLog!.actualFocusHours! * 60).round()
        : null;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      child: Padding(
        // Horizontal padding comes from GradientBackground.
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FadeInDown(
              duration: const Duration(milliseconds: 500),
              child: GreetingHeader(
                name: userName.isEmpty ? 'there' : userName,
              ),
            ),
            const SizedBox(height: 24),
            ProductivityScoreCard(
              score: scoreText,
              level: todayScore?.performanceLevel ?? '',
              feedback: feedback,
              onLogTap: () async {
                final result = await Navigator.of(
                  context,
                ).pushNamed(AppRoutes.dailyProductivityEntry);
                if (result == true) {
                  onScoreSaved?.call();
                }
              },
            ),
            if (todayScore != null && (todayScore.coverage ?? 1) < 0.999) ...[
              const SizedBox(height: 8),
              Text(
                'Partial score: ${todayScore.missingComponents.join(', ')} not recorded.',
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),
            const SectionHeader(title: 'Quick Stats', subtitle: 'Today so far'),
            const SizedBox(height: 12),
            ResponsiveCardGrid(
              children: <Widget>[
                StatCard(
                  title: 'App Usage',
                  value: today?.log.appUsageMinutes == null
                      ? 'No data'
                      : formatMinutes(today!.log.appUsageMinutes!),
                  subtitle: 'Measured',
                  icon: Icons.phone_iphone_rounded,
                  iconColor: context.brand,
                ),
                StatCard(
                  title: 'Focus',
                  value: focusMinutes == null
                      ? 'No data'
                      : formatMinutes(focusMinutes),
                  subtitle: focusMinutes == null ? null : 'Logged',
                  icon: Icons.timer_rounded,
                  iconColor: AppColors.softPurple,
                ),
                StatCard(
                  title: 'Sleep',
                  value: todayLog?.actualSleepHours == null
                      ? 'No data'
                      : formatMinutes(
                          (todayLog!.actualSleepHours! * 60).round(),
                        ),
                  subtitle: todayLog?.actualSleepHours == null
                      ? null
                      : 'Logged',
                  icon: Icons.nightlight_round,
                  iconColor: AppColors.secondaryCyan,
                ),
                StatCard(
                  title: 'Unlocks',
                  value: today?.log.phoneUnlockCount?.toString() ?? 'No data',
                  subtitle: today?.log.phoneUnlockCount == null
                      ? null
                      : 'Measured',
                  icon: Icons.lock_open_rounded,
                  iconColor: AppColors.accentGreen,
                ),
              ],
            ),
            const SizedBox(height: 24),
            RecommendationsCard(
              recommendations: snapshot?.recommendations ?? const [],
              loading: loading,
            ),
            const SizedBox(height: 24),
            ChartContainer(
              title: 'Weekly Progress',
              subtitle: snapshot == null
                  ? 'Loading saved scores…'
                  : 'Saved daily scores, last 7 days',
              child: WeeklyProductivityChart(
                data: snapshot == null
                    ? const []
                    : AnalyticsCalculator.scorePoints(
                        snapshot.history.scores,
                        DateTime.now(),
                      ),
                maxY: 100,
              ),
            ),
            if (snapshot?.loadError != null) ...[
              const SizedBox(height: 8),
              Text(
                snapshot!.loadError!,
                style: const TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            // Detailed tracking status sits below today's numbers, suggestions
            // and the weekly chart: useful, but not the first thing to read.
            TrackingStatusCard(service: activityService),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Shortcuts',
              subtitle: 'Jump into your daily tools',
            ),
            const SizedBox(height: 12),
            ResponsiveCardGrid(
              minCardWidth: 130,
              children: <Widget>[
                QuickActionTile(
                  icon: Icons.center_focus_strong_rounded,
                  title: 'Focus Mode',
                  subtitle: 'Timed sessions',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.focusMode),
                ),
                QuickActionTile(
                  icon: Icons.flag_rounded,
                  title: 'Goals',
                  subtitle: 'Track targets',
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.goals),
                ),
                QuickActionTile(
                  icon: Icons.workspace_premium_rounded,
                  title: 'Badges',
                  subtitle: 'Achievements',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.badges),
                ),
                QuickActionTile(
                  icon: Icons.settings_rounded,
                  title: 'Settings',
                  subtitle: 'Tracking & account',
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.settings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
