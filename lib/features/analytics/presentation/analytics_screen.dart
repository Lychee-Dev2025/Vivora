import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/chart_container.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/insight_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/summary_tile.dart';
import 'package:vivora/features/analytics/data/dummy_analytics_provider.dart';
import 'package:vivora/features/analytics/presentation/widgets/productivity_charts.dart';
import '../../productivity_scoring/data/services/productivity_repository.dart';
import '../../analytics/data/models/analytics_models.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _repository = ProductivityRepository();
  List<ChartDataPoint> _weeklyFocusData = DummyAnalyticsProvider.weeklyFocusData;
  List<ChartDataPoint> _sleepTrendData = DummyAnalyticsProvider.sleepTrendData;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final logs = await _repository.getWeeklyLogs(user.uid);
      if (logs.isNotEmpty && mounted) {
        setState(() {
          final sortedLogs = logs.reversed.toList();
          
          _weeklyFocusData = sortedLogs.map((log) {
            final date = (log['date'] as Timestamp).toDate();
            final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            return ChartDataPoint(
              days[date.weekday - 1],
              (log['actualFocusHours'] ?? 0).toDouble(),
            );
          }).toList();

          _sleepTrendData = sortedLogs.map((log) {
            final date = (log['date'] as Timestamp).toDate();
            final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
            return ChartDataPoint(
              days[date.weekday - 1],
              (log['actualSleepHours'] ?? 0).toDouble(),
            );
          }).toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Analytics'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: AppColors.darkText),
            )
          : null,
      body: GradientBackground(
        child: RefreshIndicator(
          onRefresh: _loadLogs,
          color: AppColors.primaryBlue,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!widget.showAppBar) ...[
                    const SizedBox(height: 10),
                    FadeInDown(
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        'Analytics',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkText,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeInDown(
                      duration: const Duration(milliseconds: 500),
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        'See your focus and wellness patterns at a glance.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.lightText,
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    child: ChartContainer(
                      title: 'Weekly Productivity',
                      subtitle: 'Focus hours trend',
                      child: WeeklyProductivityChart(
                        data: _weeklyFocusData,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 200),
                    child: ChartContainer(
                      title: 'Focus Ratio',
                      height: 240,
                      child: FocusVsDistractionChart(
                        data: DummyAnalyticsProvider.focusVsDistractionData,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 400),
                    child: const Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Top Day',
                            value: 'Saturday',
                            icon: Icons.star_rounded,
                            iconColor: AppColors.accentGreen,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: StatCard(
                            title: 'Best Streak',
                            value: '5 Days',
                            icon: Icons.local_fire_department_rounded,
                            iconColor: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 600),
                    child: ChartContainer(
                      title: 'Sleep Trend',
                      subtitle: 'Hours slept per night',
                      child: SleepTrendChart(
                        data: _sleepTrendData,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(
                    title: 'Top App Usage',
                    subtitle: 'Where your time goes',
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: DummyAnalyticsProvider.topApps.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final app = DummyAnalyticsProvider.topApps[index];
                      return FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        delay: Duration(milliseconds: 400 + (index.toInt() * 100)),
                        child: SummaryTile(
                          label: app.appName,
                          value: app.timeSpent,
                          icon: Icons.apps_rounded,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    duration: const Duration(milliseconds: 600),
                    delay: const Duration(milliseconds: 700),
                    child: const InsightCard(
                      title: 'Smart Tip',
                      insight:
                          'You are most productive on Saturday mornings. Try scheduling your hardest tasks then for maximum efficiency.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
