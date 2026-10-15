import 'dart:async';

import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/widgets/ui_kit.dart';
import 'package:vivora/core/utils/friendly_error.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import 'package:vivora/core/widgets/app_bar_title.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/info_card.dart';
import '../../../core/widgets/report_card.dart';
import '../../activity_monitoring/data/models/activity_date_utils.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../../activity_monitoring/data/models/daily_activity_log.dart';
import '../../activity_monitoring/data/repositories/activity_repository.dart';
import '../../analytics/data/analytics_calculator.dart';
import '../../productivity_scoring/data/models/productivity_models.dart';
import '../../productivity_scoring/data/services/productivity_repository.dart';

/// Daily reports (last 14 days) plus weekly (7-day) and monthly (30-day)
/// summaries computed from the same saved records as the dashboard.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _repository = ProductivityRepository();
  final _activityRepository = ActivityRepository();

  List<SavedDailyScore> _scores = const <SavedDailyScore>[];
  List<DailyActivityLog> _activity = const <DailyActivityLog>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    ProductivityRepository.revision.addListener(_onRevision);
    _loadReports();
  }

  @override
  void dispose() {
    ProductivityRepository.revision.removeListener(_onRevision);
    super.dispose();
  }

  void _onRevision() => unawaited(_loadReports());

  Future<void> _loadReports() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _repository.getScoresForLastDays(user.uid, days: 30),
        _activityRepository.getActivityLogsForLastDays(uid: user.uid, days: 30),
      ]).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _scores = results[0] as List<SavedDailyScore>;
        _activity = results[1] as List<DailyActivityLog>;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = friendlyError(error, action: 'load your reports'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReportsView(
      scores: _scores,
      activity: _activity,
      loading: _loading,
      error: _error,
      showAppBar: widget.showAppBar,
      onRefresh: _loadReports,
    );
  }
}

/// The Reports layout, driven entirely by its parameters.
class ReportsView extends StatelessWidget {
  const ReportsView({
    super.key,
    required this.scores,
    required this.activity,
    this.loading = false,
    this.error,
    this.showAppBar = false,
    this.onRefresh,
    this.now,
  });

  final List<SavedDailyScore> scores;
  final List<DailyActivityLog> activity;
  final bool loading;
  final String? error;
  final bool showAppBar;
  final Future<void> Function()? onRefresh;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final DateTime now = this.now ?? DateTime.now();
    final PeriodSummary week = PeriodSummary.of(
      scores: scores,
      activity: activity,
      today: now,
      days: 7,
    );
    final PeriodSummary month = PeriodSummary.of(
      scores: scores,
      activity: activity,
      today: now,
      days: 30,
    );
    final Set<String> lastFourteen = ActivityDateUtils.lastDays(
      now,
      14,
    ).map(ActivityDateUtils.dayKey).toSet();
    final List<SavedDailyScore> daily = scores
        .where((s) => lastFourteen.contains(ActivityDateUtils.dayKey(s.date)))
        .toList()
        .reversed
        .toList();

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const AppBarTitle('Reports'),
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: context.palette.textPrimary),
            )
          : null,
      body: GradientBackground(
        child: RefreshIndicator(
          onRefresh: onRefresh ?? () async {},
          color: context.brand,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            // Horizontal padding comes from GradientBackground.
            padding: const EdgeInsets.only(bottom: 30),
            children: <Widget>[
              if (!showAppBar) ...[
                const SizedBox(height: 10),
                FadeInDown(
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    'Reports',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Summaries of your saved days. Averages only use days that have records.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (loading && scores.isEmpty) const LinearProgressIndicator(),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StateMessage.error(
                    message: error!,
                    onAction: onRefresh == null ? null : () => onRefresh!(),
                  ),
                ),
              _SummaryCard(
                title: 'Weekly Report',
                subtitle: 'Last 7 days',
                summary: week,
              ),
              const SizedBox(height: 12),
              _SummaryCard(
                title: 'Monthly Report',
                subtitle: 'Last 30 days',
                summary: month,
              ),
              const SizedBox(height: 24),
              Text(
                'Daily Reports',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.brand,
                ),
              ),
              const SizedBox(height: 12),
              if (!loading && daily.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'No daily logs in the last 14 days. Log today from the Home tab.',
                    style: TextStyle(color: context.palette.textSecondary),
                  ),
                ),
              for (final SavedDailyScore score in daily)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ReportCard(
                    title:
                        'Daily Report · ${AnalyticsCalculator.formatDate(score.date)}',
                    description: score.feedbackMessage ?? '',
                    quickStats: <Map<String, String>>[
                      {
                        'label': 'Score',
                        'value': score.overallScore == null
                            ? '--'
                            : '${score.overallScore!.round()}',
                      },
                      {
                        'label': 'Focus',
                        'value': score.log.actualFocusHours == null
                            ? '--'
                            : formatMinutes(
                                (score.log.actualFocusHours! * 60).round(),
                              ),
                      },
                      {
                        'label': 'Level',
                        'value': score.performanceLevel ?? '--',
                      },
                    ],
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.reportDetail,
                      arguments: score.log.dayKey,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.subtitle,
    required this.summary,
  });

  final String title;
  final String subtitle;
  final PeriodSummary summary;

  @override
  Widget build(BuildContext context) {
    String hours(double? h) =>
        h == null ? '--' : formatMinutes((h * 60).round());
    final rows = <(String, String)>[
      ('Days logged', '${summary.loggedDays} of ${summary.days}'),
      (
        'Average score',
        summary.averageScore == null
            ? '--'
            : '${summary.averageScore!.round()}',
      ),
      ('Average sleep', hours(summary.averageSleepHours)),
      ('Average focus', hours(summary.averageFocusHours)),
      (
        'Average app usage',
        summary.averageAppUsageMinutes == null
            ? '--'
            : '${formatMinutes(summary.averageAppUsageMinutes!.round())} (${summary.measuredDays} days measured)',
      ),
      (
        'Best day',
        summary.topDay == null
            ? 'Need 2+ logged days'
            : '${AnalyticsCalculator.formatDate(summary.topDay!.date)} (${summary.topDay!.score.round()})',
      ),
    ];
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          Text(
            subtitle,
            style: TextStyle(color: context.palette.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final (String label, String value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(color: context.palette.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
