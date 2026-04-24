import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/report_card.dart';
import 'package:vivora/features/analytics/data/dummy_analytics_provider.dart';
import '../../productivity_scoring/data/services/productivity_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repository = ProductivityRepository();
  List<Map<String, dynamic>> _realReports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final logs = await _repository.getWeeklyLogs(user.uid);
      if (logs.isNotEmpty && mounted) {
        setState(() {
          _realReports = logs.map((log) {
            final date = (log['date'] as Timestamp).toDate();
            final dateStr = "${date.day}/${date.month}/${date.year}";
            
            return {
              'title': 'Daily Report - $dateStr',
              'summary': log['feedbackMessage'] ?? 'Keep up the good work!',
              'quickStats': [
                {'label': 'Score', 'value': '${(log['overallScore'] ?? 0).toInt()}%'},
                {'label': 'Focus', 'value': '${(log['actualFocusHours'] ?? 0).toStringAsFixed(1)}h'},
                {'label': 'Level', 'value': log['performanceLevel'] ?? 'Medium'},
              ],
            };
          }).toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dummyReports = DummyAnalyticsProvider.reports;

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Reports'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: AppColors.darkText),
            )
          : null,
      body: GradientBackground(
        child: RefreshIndicator(
          onRefresh: _loadReports,
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
                        'Reports',
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
                        'Detailed summaries for your day, week, and month.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.lightText,
                            ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  
                  if (_realReports.isNotEmpty) ...[
                    const Text(
                      'Personal Daily Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._realReports.asMap().entries.map((entry) {
                      final index = entry.key;
                      final report = entry.value;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: FadeInUp(
                          duration: const Duration(milliseconds: 600),
                          delay: Duration(milliseconds: 100 + (index * 50)),
                          child: ReportCard(
                            title: report['title'],
                            description: report['summary'],
                            quickStats: List<Map<String, String>>.from(report['quickStats']),
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                AppRoutes.reportDetail,
                                arguments: report['title'],
                              );
                            },
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                  ],

                  const Text(
                    'System Reports',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...dummyReports.asMap().entries.map((entry) {
                    final index = entry.key;
                    final report = entry.value;

                    final quickStats = report.stats.entries.take(3).map((e) {
                      return {'label': e.key, 'value': e.value};
                    }).toList();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        delay: Duration(milliseconds: 200 + (index * 100)),
                        child: ReportCard(
                          title: report.title,
                          description: report.summary,
                          quickStats: quickStats,
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              AppRoutes.reportDetail,
                              arguments: report.title,
                            );
                          },
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
