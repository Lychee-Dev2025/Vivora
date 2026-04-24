import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.title});

  final String title;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _repository = ProductivityRepository();
  Map<String, dynamic>? _realLog;

  @override
  void initState() {
    super.initState();
    if (widget.title.startsWith('Daily Report')) {
      _loadRealLog();
    }
  }

  Future<void> _loadRealLog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final parts = widget.title.split(' - ');
      if (parts.length > 1) {
        final dateParts = parts[1].split('/');
        if (dateParts.length == 3) {
          final date = DateTime(
            int.parse(dateParts[2]),
            int.parse(dateParts[1]),
            int.parse(dateParts[0]),
          );
          
          final allLogs = await _repository.getWeeklyLogs(user.uid);
          final match = allLogs.firstWhere(
            (l) {
              final d = (l['date'] as Timestamp).toDate();
              return d.year == date.year && d.month == date.month && d.day == date.day;
            },
            orElse: () => {},
          );
          
          if (mounted && match.isNotEmpty) {
            setState(() {
              _realLog = match;
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_realLog != null) {
      return _buildRealReportView(_realLog!);
    }

    final report = DummyAnalyticsProvider.reports.firstWhere(
      (r) => r.title == widget.title,
      orElse: () => DummyAnalyticsProvider.reports.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 40, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    report.title,
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
                    report.summary,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.lightText,
                        ),
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(
                  title: 'Key Statistics',
                  subtitle: 'Quick performance overview',
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 130,
                  ),
                  itemCount: report.stats.length,
                  itemBuilder: (context, index) {
                    final key = report.stats.keys.elementAt(index);
                    final value = report.stats[key]!;
                    return FadeInUp(
                      duration: const Duration(milliseconds: 500),
                      delay: Duration(milliseconds: 200 + (index * 100)),
                      child: StatCard(
                        title: key,
                        value: value,
                        icon: _getIconForStat(key),
                        iconColor: _getColorForStat(index),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 400),
                  child: ChartContainer(
                    title: 'Focus Trend',
                    subtitle: 'Performance over time',
                    child: WeeklyProductivityChart(data: report.trendData),
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(
                  title: 'Top Used Apps',
                  subtitle: 'App usage breakdown',
                ),
                const SizedBox(height: 12),
                ...report.topApps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final app = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: FadeInUp(
                        duration: const Duration(milliseconds: 500),
                        delay: Duration(milliseconds: 500 + (index.toInt() * 100)),
                        child: SummaryTile(
                        label: app.appName,
                        value: app.timeSpent,
                        icon: Icons.apps_rounded,
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 24),
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  delay: const Duration(milliseconds: 700),
                  child: InsightCard(
                    title: 'Performance Summary',
                    insight: report.performanceSummary,
                    icon: Icons.assignment_turned_in_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRealReportView(Map<String, dynamic> log) {
    final stats = {
      'Overall Score': '${(log['overallScore'] ?? 0).toInt()}%',
      'Performance': log['performanceLevel'] ?? 'Medium',
      'Focus Hours': '${(log['actualFocusHours'] ?? 0).toStringAsFixed(1)}h',
      'Sleep Hours': '${(log['actualSleepHours'] ?? 0).toStringAsFixed(1)}h',
      'Screen Time': '${(log['actualScreenTimeHours'] ?? 0).toStringAsFixed(1)}h',
      'Consistency': '${(log['consistencyScore'] ?? 0).toInt()}%',
    };

    final suggestions = List<String>.from(log['suggestions'] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
      ),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 40, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInDown(
                  child: Text(
                    widget.title,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.darkText),
                  ),
                ),
                const SizedBox(height: 8),
                FadeInDown(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    log['feedbackMessage'] ?? 'Details for your daily performance.',
                    style: const TextStyle(color: AppColors.lightText, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 30),
                const SectionHeader(title: 'Detailed Metrics'),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 130,
                  ),
                  itemCount: stats.length,
                  itemBuilder: (context, index) {
                    final key = stats.keys.elementAt(index);
                    final value = stats[key]!;
                    return FadeInUp(
                      delay: Duration(milliseconds: 200 + (index * 50)),
                      child: StatCard(
                        title: key,
                        value: value,
                        icon: _getIconForStat(key),
                        iconColor: _getColorForStat(index),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 30),
                if (suggestions.isNotEmpty) ...[
                  const SectionHeader(title: 'Personalized Suggestions'),
                  const SizedBox(height: 12),
                  ...suggestions.asMap().entries.map((entry) => FadeInUp(
                    delay: Duration(milliseconds: 500 + (entry.key * 100)),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded, color: AppColors.primaryBlue),
                          const SizedBox(width: 12),
                          Expanded(child: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w500))),
                        ],
                      ),
                    ),
                  )),
                ],
                const SizedBox(height: 30),
                FadeInUp(
                  delay: const Duration(milliseconds: 800),
                  child: InsightCard(
                    title: 'Final Summary',
                    insight: "Based on your performance, you are in the '${log['performanceLevel']}' category. Keep pushing towards your goals to reach 'Excellent'!",
                    icon: Icons.auto_awesome_rounded,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForStat(String key) {
    key = key.toLowerCase();
    if (key.contains('screen')) return Icons.phone_iphone_rounded;
    if (key.contains('focus')) return Icons.timer_rounded;
    if (key.contains('sleep')) return Icons.nightlight_round;
    if (key.contains('score') || key.contains('performance')) {
      return Icons.trending_up_rounded;
    }
    if (key.contains('consistency')) return Icons.repeat_rounded;
    return Icons.insights_rounded;
  }

  Color _getColorForStat(int index) {
    const colors = [
      AppColors.primaryBlue,
      AppColors.softPurple,
      AppColors.secondaryCyan,
      AppColors.accentGreen,
      Colors.orange,
      Colors.pinkAccent,
    ];
    return colors[index % colors.length];
  }
}
