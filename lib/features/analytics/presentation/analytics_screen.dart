import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import 'package:vivora/core/widgets/app_bar_title.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/chart_container.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/summary_tile.dart';
import '../../activity_monitoring/data/models/activity_sync_snapshot.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../../activity_monitoring/data/models/daily_activity_log.dart';
import '../../activity_monitoring/data/services/activity_sync_service.dart';
import '../../activity_monitoring/presentation/widgets/tracking_status_card.dart';
import '../../behavior_analysis/presentation/behavior_insights_section.dart';
import '../../insights/services/insights_service.dart';
import '../data/analytics_calculator.dart';
import 'widgets/productivity_charts.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _activityService = ActivitySyncService.instance;
  final _insights = InsightsService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_insights.ensureLoaded());
    });
  }

  Future<void> _refresh() async {
    await _activityService.syncNow(force: true);
    await _insights.reload();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _insights.snapshot,
        _activityService.today,
      ]),
      builder: (context, _) => AnalyticsView(
        showAppBar: widget.showAppBar,
        snapshot: _insights.snapshot.value,
        today: _activityService.today.value,
        onRefresh: _refresh,
        onCategoryChosen: _activityService.setCategoryOverride,
      ),
    );
  }
}

/// The Analytics layout, driven entirely by its parameters.
class AnalyticsView extends StatelessWidget {
  const AnalyticsView({
    super.key,
    required this.snapshot,
    required this.today,
    this.showAppBar = false,
    this.onRefresh,
    this.onCategoryChosen,
    this.now,
  });

  final InsightsSnapshot? snapshot;
  final TodayActivity? today;
  final bool showAppBar;
  final Future<void> Function()? onRefresh;
  final Future<void> Function(String packageName, AppCategory category)?
  onCategoryChosen;

  /// Reference "today" for the 7-day windows; defaults to the clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const AppBarTitle('Analytics'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: context.palette.textPrimary),
            )
          : null,
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
    final DailyActivityLog? log = today?.log;
    final DateTime now = this.now ?? DateTime.now();
    final scores = snapshot?.history.scores ?? const [];
    final topDay = AnalyticsCalculator.topDay(scores);
    final int bestStreak = AnalyticsCalculator.bestStreak(scores);
    final int currentStreak = AnalyticsCalculator.currentStreak(scores, now);
    final focusRatio = AnalyticsCalculator.appFocusRatio(log);

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
            if (!showAppBar) ...[
              const SizedBox(height: 10),
              FadeInDown(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  'Analytics',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Measured device data and your saved daily logs.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Today',
              subtitle: 'Measured on this phone',
            ),
            const SizedBox(height: 12),
            ResponsiveCardGrid(
              children: <Widget>[
                StatCard(
                  title: 'App Usage',
                  value: log?.appUsageMinutes == null
                      ? 'No data'
                      : formatMinutes(log!.appUsageMinutes!),
                  icon: Icons.phone_iphone_rounded,
                  iconColor: context.brand,
                ),
                StatCard(
                  title: 'Screen Unlocked',
                  value: log == null
                      ? 'No data'
                      : log.screenTimeMinutes == null
                      ? 'Unavailable'
                      : formatMinutes(log.screenTimeMinutes!),
                  icon: Icons.smartphone_rounded,
                  iconColor: AppColors.softPurple,
                ),
                StatCard(
                  title: 'Unlocks',
                  value: log?.phoneUnlockCount?.toString() ?? 'No data',
                  icon: Icons.lock_open_rounded,
                  iconColor: AppColors.secondaryCyan,
                ),
                StatCard(
                  title: 'Movement',
                  value: TrackingStatusCard.movementLabel(log),
                  icon: Icons.directions_walk_rounded,
                  iconColor: AppColors.accentGreen,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'App usage = time apps were on screen (home screen excluded), the figure Digital Wellbeing shows. '
              'Screen unlocked also includes time on the home screen.',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            ChartContainer(
              title: 'Weekly Productivity',
              subtitle: snapshot == null
                  ? 'Loading…'
                  : 'Saved scores · ${AnalyticsCalculator.scorePoints(scores, now).length} of 7 days logged',
              child: snapshot == null
                  ? const Center(child: CircularProgressIndicator())
                  : WeeklyProductivityChart(
                      data: AnalyticsCalculator.scorePoints(scores, now),
                      maxY: 100,
                    ),
            ),
            const SizedBox(height: 20),
            ChartContainer(
              title: 'Daily App Usage',
              subtitle: 'Measured minutes per day, last 7 days',
              child: snapshot == null
                  ? const Center(child: CircularProgressIndicator())
                  : SleepTrendChart(
                      data: AnalyticsCalculator.appUsagePoints(
                        snapshot.history.activityLogs,
                        now,
                      ),
                      unit: 'm',
                    ),
            ),
            const SizedBox(height: 20),
            ChartContainer(
              title: 'App Focus Ratio (today)',
              subtitle:
                  'Productive vs distracting app time. Neutral and uncategorized apps are not counted.',
              height: null,
              child: FocusVsDistractionChart(data: focusRatio),
            ),
            const SizedBox(height: 16),
            ResponsiveCardGrid(
              children: <Widget>[
                StatCard(
                  title: 'Top Day',
                  value: topDay == null
                      ? 'Need 2+ days'
                      : '${AnalyticsCalculator.formatDate(topDay.date)} · ${topDay.score.round()}',
                  subtitle: topDay?.tied == true
                      ? 'Tied, most recent shown'
                      : null,
                  icon: Icons.star_rounded,
                  iconColor: AppColors.accentGreen,
                ),
                StatCard(
                  title: 'Logging Streak',
                  value: bestStreak == 0
                      ? 'No logs yet'
                      : '$currentStreak day(s)',
                  subtitle: bestStreak == 0
                      ? null
                      : 'Best: $bestStreak in 14 days',
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 20),
            ChartContainer(
              title: 'Sleep Trend',
              subtitle: 'Logged hours of sleep',
              child: snapshot == null
                  ? const Center(child: CircularProgressIndicator())
                  : SleepTrendChart(
                      data: AnalyticsCalculator.sleepPoints(scores, now),
                    ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Patterns & Habits',
              subtitle:
                  'Detected from your saved logs, Focus Mode and measured usage',
            ),
            const SizedBox(height: 12),
            BehaviorInsightsSection(analyses: snapshot?.analyses),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'App Usage Today',
              subtitle: 'Tap an app to change its category',
            ),
            const SizedBox(height: 8),
            Text(
              log?.lastSyncAt == null
                  ? 'Not synced yet'
                  : 'Last device sync: ${_time(log!.lastSyncAt!)}',
              style: TextStyle(color: context.palette.textSecondary),
            ),
            const SizedBox(height: 8),
            if (today == null || today.apps.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'No application usage recorded yet today.',
                  style: TextStyle(color: context.palette.textSecondary),
                ),
              )
            else
              for (final AppUsageEntry app in today.apps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _pickCategory(context, app),
                    child: SummaryTile(
                      label: app.displayName,
                      value: app.durationLabel,
                      icon: Icons.apps_rounded,
                      iconBase64: app.iconBase64,
                      subtitle: app.categoryIsUserOverride
                          ? '${app.category.label} (your choice)'
                          : app.category.label,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context, AppUsageEntry app) async {
    final AppCategory? choice = await showModalBottomSheet<AppCategory>(
      context: context,
      // Scrollable and allowed to grow: with large fonts the five rows do
      // not fit the default half-height sheet.
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: Text(
                  app.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Applies to all days. "Uncategorized" restores the default.',
                ),
              ),
              for (final AppCategory category in AppCategory.values)
                ListTile(
                  title: Text(category.label),
                  trailing: category == app.category
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.of(context).pop(category),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null) {
      return;
    }
    try {
      await onCategoryChosen?.call(app.packageName, choice);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Category saved on this device; cloud update failed: $error',
            ),
          ),
        );
      }
    }
  }

  String _time(DateTime time) {
    final local = time.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
