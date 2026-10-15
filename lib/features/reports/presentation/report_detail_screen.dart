import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/widgets/ui_kit.dart';
import 'package:vivora/core/utils/friendly_error.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import 'package:vivora/core/widgets/app_bar_title.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/info_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stat_card.dart';
import '../../../core/widgets/summary_tile.dart';
import '../../activity_monitoring/data/models/activity_date_utils.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../../activity_monitoring/data/models/daily_activity_log.dart';
import '../../activity_monitoring/data/repositories/activity_repository.dart';
import '../../productivity_scoring/data/models/productivity_models.dart';
import '../../productivity_scoring/data/services/productivity_repository.dart';

/// Full report for one day: the saved score with its components, the logged
/// inputs and the measured device data for the same local date.
class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({super.key, required this.dayKey});

  /// `yyyy-MM-dd`.
  final String dayKey;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final _repository = ProductivityRepository();
  final _activityRepository = ActivityRepository();

  SavedDailyScore? _score;
  DailyActivityLog? _activity;
  List<AppUsageEntry> _apps = const <AppUsageEntry>[];
  bool _loading = true;
  String? _error;

  DateTime? get _date => ActivityDateUtils.parseKey(widget.dayKey);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    final DateTime? date = _date;
    if (user == null || date == null) {
      setState(() {
        _loading = false;
        _error = 'Report not available.';
      });
      return;
    }
    try {
      final score = await _repository
          .getDailyScore(user.uid, date)
          .timeout(const Duration(seconds: 10));
      final activity = await _activityRepository
          .getDailyActivityLog(uid: user.uid, date: date)
          .timeout(const Duration(seconds: 10));
      final apps = activity == null
          ? const <AppUsageEntry>[]
          : await _activityRepository
                .getDailyAppUsage(
                  uid: user.uid,
                  date: date,
                  captureId: activity.captureId,
                )
                .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _score = score;
        _activity = activity;
        _apps = apps;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = friendlyError(error, action: 'load this report'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ReportDetailView(
      dayKey: widget.dayKey,
      score: _score,
      activity: _activity,
      apps: _apps,
      loading: _loading,
      error: _error,
      onRetry: () {
        setState(() {
          _error = null;
          _loading = true;
        });
        _load();
      },
    );
  }
}

/// The Daily Report layout, driven entirely by its parameters.
class ReportDetailView extends StatelessWidget {
  const ReportDetailView({
    super.key,
    required this.dayKey,
    required this.score,
    required this.activity,
    this.apps = const <AppUsageEntry>[],
    this.loading = false,
    this.error,
    this.onRetry,
  });

  final String dayKey;
  final SavedDailyScore? score;
  final DailyActivityLog? activity;
  final List<AppUsageEntry> apps;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  DateTime? get _date => ActivityDateUtils.parseKey(dayKey);

  @override
  Widget build(BuildContext context) {
    // The AppBar keeps a short title; the full date is a heading in the body,
    // where it can wrap instead of being cut off ("Daily Report · Thu 1…").
    const String title = 'Daily Report';
    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.palette.textPrimary),
      ),
      body: GradientBackground(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                children: _buildContent(context),
              ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context) {
    if (error != null) {
      return <Widget>[StateMessage.error(message: error!, onAction: onRetry)];
    }
    final SavedDailyScore? score = this.score;
    final DailyActivityLog? activity = this.activity;
    if (score == null && activity == null) {
      return <Widget>[
        Text(
          'No records for this day.',
          style: TextStyle(color: context.palette.textSecondary),
        ),
      ];
    }
    String hours(double? h) =>
        h == null ? 'Not recorded' : formatMinutes((h * 60).round());

    final DateTime? date = _date;
    return <Widget>[
      if (date != null) ...[
        Text(
          _longDate(date),
          softWrap: true,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
      ],
      if (score != null) ...[
        Text(
          score.overallScore == null
              ? 'No score'
              : 'Score ${score.overallScore!.round()} · ${score.performanceLevel ?? ''}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: context.palette.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          score.feedbackMessage ?? '',
          style: TextStyle(color: context.palette.textSecondary),
        ),
        if (score.missingComponents.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Not recorded (excluded from the score): ${score.missingComponents.join(', ')}.',
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 20),
        const SectionHeader(title: 'Score Components'),
        const SizedBox(height: 12),
        InfoCard(
          child: Column(
            children: <Widget>[
              for (final entry in <(String, String)>[
                ('Focus (30%)', 'focus'),
                ('Sleep (20%)', 'sleep'),
                ('Consistency (20%)', 'consistency'),
                ('Physical activity (15%)', 'activity'),
                ('Low distraction (15%)', 'lowDistraction'),
              ])
                _row(
                  context,
                  entry.$1,
                  score.componentScores[entry.$2] == null
                      ? 'Not recorded'
                      : '${score.componentScores[entry.$2]!.round()}/100',
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Logged Inputs'),
        const SizedBox(height: 12),
        InfoCard(
          child: Column(
            children: <Widget>[
              _row(context, 'Sleep', hours(score.log.actualSleepHours)),
              _row(context, 'Study', hours(score.log.actualStudyHours)),
              _row(context, 'Deep focus', hours(score.log.actualFocusHours)),
              _row(
                context,
                score.log.screenTimeFromDevice
                    ? 'Logged screen time (prefilled from device)'
                    : 'Logged screen time',
                hours(score.log.actualScreenTimeHours),
              ),
              _row(
                context,
                'Consistency',
                score.log.consistencyScore == null
                    ? 'Not recorded'
                    : '${score.log.consistencyScore!.round()}%',
              ),
              _row(
                context,
                'Physical activity',
                score.log.activityScore == null
                    ? 'Not rated'
                    : '${score.log.activityScore!.round()}%',
              ),
            ],
          ),
        ),
      ],
      if (activity != null) ...[
        const SizedBox(height: 20),
        const SectionHeader(title: 'Measured on Device'),
        const SizedBox(height: 12),
        ResponsiveCardGrid(
          children: <Widget>[
            StatCard(
              title: 'Measured App Usage',
              value: activity.appUsageMinutes == null
                  ? '--'
                  : formatMinutes(activity.appUsageMinutes!),
              icon: Icons.phone_iphone_rounded,
            ),
            if (activity.screenTimeMinutes != null)
              StatCard(
                title: 'Screen Unlocked',
                value: formatMinutes(activity.screenTimeMinutes!),
                icon: Icons.smartphone_rounded,
                iconColor: AppColors.softPurple,
              ),
            StatCard(
              title: 'Unlocks',
              value: activity.phoneUnlockCount?.toString() ?? '--',
              icon: Icons.lock_open_rounded,
              iconColor: AppColors.accentGreen,
            ),
          ],
        ),
        if (score?.log.actualScreenTimeHours != null) ...[
          const SizedBox(height: 10),
          Text(
            'Logged screen time is entered by you (it can be prefilled from the '
            'device when you log). Measured app usage comes from Android activity '
            'tracking and keeps growing during the day, so the two can differ. '
            'The Low Distraction score uses the logged value.',
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
        if (apps.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionHeader(title: 'Apps Used'),
          const SizedBox(height: 12),
          InfoCard(
            child: Column(
              children: <Widget>[
                for (int i = 0; i < apps.length && i < 8; i++) ...[
                  if (i > 0) const Divider(height: 20),
                  UsageRow(
                    label: apps[i].displayName,
                    subtitle: apps[i].category.label,
                    value: apps[i].durationLabel,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
      if (score != null && score.suggestions.isNotEmpty) ...[
        const SizedBox(height: 20),
        const SectionHeader(title: 'Suggestions'),
        const SizedBox(height: 12),
        for (final String suggestion in score.suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InfoCard(
              child: Row(
                children: <Widget>[
                  Icon(Icons.lightbulb_outline_rounded, color: context.brand),
                  const SizedBox(width: 12),
                  Expanded(child: Text(suggestion)),
                ],
              ),
            ),
          ),
      ],
    ];
  }

  static String _longDate(DateTime date) {
    const List<String> days = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
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
    );
  }
}
