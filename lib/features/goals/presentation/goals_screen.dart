import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/widgets/ui_kit.dart';
import 'package:vivora/core/utils/friendly_error.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import 'package:vivora/core/widgets/app_bar_title.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/info_card.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../../activity_monitoring/data/services/activity_sync_service.dart';
import '../../first_time_setup/data/models/user_profile_model.dart';
import '../../first_time_setup/data/services/user_profile_service.dart';
import '../../insights/services/insights_service.dart';
import '../../productivity_scoring/data/models/productivity_models.dart';
import '../../productivity_scoring/data/services/productivity_score_service.dart';

/// Today's progress against the goals stored in the user's profile. Values
/// come from today's measured app usage and today's saved log only.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _profileService = UserProfileService();
  UserGoals? _goals;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    unawaited(InsightsService.instance.ensureLoaded());
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final profile = await _profileService
          .getUserProfile(user.uid)
          .timeout(Duration(seconds: 8));
      if (mounted) setState(() => _goals = profile?.goals ?? UserGoals());
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = friendlyError(error, action: 'load your goals'),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(GoalKind kind) async {
    final UserGoals goals = _goals ?? UserGoals();
    final double current =
        ProductivityScoreService.parseHours(kind.read(goals)) ??
        kind.defaultHours;

    final double? result = await showGoalHoursDialog(
      context,
      title: 'Edit ${kind.title}',
      initialHours: current,
      maxHours: kind.maxHours,
    );
    if (result == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final String text = result % 1 == 0 ? '${result.toInt()}h' : '${result}h';
    final UserGoals updated = kind.write(goals, text);
    setState(() => _goals = updated);
    try {
      await _profileService.updateGoals(user.uid, updated);
      unawaited(InsightsService.instance.reload());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${kind.title} set to ${formatMinutes((result * 60).round())}',
            ),
          ),
        );
      }
    } catch (error) {
      setState(() => _goals = goals);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(error, action: 'save your goal')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        ActivitySyncService.instance.today,
        InsightsService.instance.snapshot,
      ]),
      builder: (context, _) => GoalsView(
        goals: _goals,
        loading: _loading,
        error: _error,
        appUsageMinutes:
            ActivitySyncService.instance.today.value?.log.appUsageMinutes,
        todayLog:
            InsightsService.instance.snapshot.value?.history.todayScore?.log,
        onEdit: _edit,
        onRetry: () {
          setState(() {
            _error = null;
            _loading = true;
          });
          _load();
        },
      ),
    );
  }
}

/// The Goals layout, driven entirely by its parameters.
class GoalsView extends StatelessWidget {
  const GoalsView({
    super.key,
    required this.goals,
    required this.appUsageMinutes,
    required this.todayLog,
    this.loading = false,
    this.error,
    this.onEdit,
    this.onRetry,
  });

  final UserGoals? goals;
  final int? appUsageMinutes;
  final DailyProductivityLog? todayLog;
  final bool loading;
  final String? error;
  final void Function(GoalKind kind)? onEdit;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppBarTitle('Goals')),
      body: GradientBackground(child: _buildList(context)),
    );
  }

  Widget _buildList(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator());
    }
    final UserGoals goals = this.goals ?? UserGoals();
    final int? appMinutes = appUsageMinutes;
    final DailyProductivityLog? log = todayLog;

    double? minutesOf(double? hours) => hours == null ? null : hours * 60;
    final Map<GoalKind, double?> actualMinutes = <GoalKind, double?>{
      GoalKind.screen: appMinutes?.toDouble(),
      GoalKind.sleep: minutesOf(log?.actualSleepHours),
      GoalKind.study: minutesOf(log?.actualStudyHours),
      GoalKind.focus: minutesOf(log?.actualFocusHours),
    };

    return ListView(
      physics: BouncingScrollPhysics(),
      children: <Widget>[
        Text(
          'Your Targets',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 8),
        Text(
          'Today\'s progress. Screen time is measured; sleep, study and focus come from today\'s log.',
        ),
        if (error != null) ...[
          SizedBox(height: 8),
          StateMessage.error(message: error!, onAction: onRetry),
        ],
        SizedBox(height: 20),
        for (final GoalKind kind in GoalKind.values) ...[
          _GoalCard(
            kind: kind,
            targetHours: ProductivityScoreService.parseHours(kind.read(goals)),
            actualMinutes: actualMinutes[kind],
            onEdit: () => onEdit?.call(kind),
          ),
          SizedBox(height: 12),
        ],
      ],
    );
  }
}

enum GoalKind {
  screen(
    'Screen Time Limit',
    Icons.phone_android_rounded,
    AppColors.primaryBlue,
    12,
    3,
    isLimit: true,
  ),
  sleep('Sleep Goal', Icons.nightlight_round, AppColors.softPurple, 12, 8),
  study(
    'Study Goal',
    Icons.auto_stories_rounded,
    AppColors.secondaryCyan,
    14,
    4,
  ),
  focus(
    'Focus Goal',
    Icons.center_focus_strong_rounded,
    AppColors.accentGreen,
    10,
    2,
  );

  const GoalKind(
    this.title,
    this.icon,
    this.color,
    this.maxHours,
    this.defaultHours, {
    this.isLimit = false,
  });

  final String title;
  final IconData icon;
  final Color color;
  final double maxHours;
  final double defaultHours;
  final bool isLimit;

  String read(UserGoals g) => switch (this) {
    GoalKind.screen => g.targetScreenTimeLimit,
    GoalKind.sleep => g.targetSleepHours,
    GoalKind.study => g.targetStudyHours,
    GoalKind.focus => g.targetFocusHours,
  };

  UserGoals write(UserGoals g, String value) => UserGoals(
    targetScreenTimeLimit: this == GoalKind.screen
        ? value
        : g.targetScreenTimeLimit,
    targetSleepHours: this == GoalKind.sleep ? value : g.targetSleepHours,
    targetStudyHours: this == GoalKind.study ? value : g.targetStudyHours,
    targetFocusHours: this == GoalKind.focus ? value : g.targetFocusHours,
    productivityGoalType: g.productivityGoalType,
  );
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.kind,
    required this.targetHours,
    required this.actualMinutes,
    required this.onEdit,
  });

  final GoalKind kind;
  final double? targetHours;
  final double? actualMinutes;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final double? target = targetHours == null ? null : targetHours! * 60;
    final double? progress = target == null || actualMinutes == null
        ? null
        : actualMinutes! / target;
    final bool over = kind.isLimit && (progress ?? 0) > 1;
    final String status = target == null
        ? 'No goal set'
        : actualMinutes == null
        ? 'Not recorded today'
        : kind.isLimit
        ? (over
              ? 'Over limit by ${formatMinutes((actualMinutes! - target).round())}'
              : 'Within limit')
        : (progress! >= 1
              ? 'Goal reached'
              : '${(progress * 100).round()}% of goal');
    final Color barColor = over ? context.palette.danger : kind.color;

    return InfoCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kind.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(kind.icon, color: kind.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  kind.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 18),
                color: context.palette.textSecondary,
                tooltip: 'Edit goal',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Wrap: on a narrow card or with large fonts the target moves under
          // the value instead of overflowing the row.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: <Widget>[
              Text(
                actualMinutes == null
                    ? '--'
                    : formatMinutes(actualMinutes!.round()),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  // Accent stays on the bar; the number uses readable text.
                  color: over
                      ? context.palette.danger
                      : context.palette.textPrimary,
                ),
              ),
              Text(
                target == null
                    ? 'Target: not set'
                    : 'Target: ${kind.isLimit ? '≤ ' : ''}${formatMinutes(target.round())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (progress ?? 0).clamp(0, 1).toDouble(),
              minHeight: 8,
              backgroundColor: context.palette.surfaceMuted,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              status,
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slider dialog for a goal in hours. Scrollable so it never overflows on a
/// short screen with large fonts.
Future<double?> showGoalHoursDialog(
  BuildContext context, {
  required String title,
  required double initialHours,
  required double maxHours,
}) {
  double value = initialHours.clamp(0.5, maxHours).toDouble();
  return showDialog<double>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              formatMinutes((value * 60).round()),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            Slider(
              value: value,
              min: 0.5,
              max: maxHours,
              divisions: ((maxHours - 0.5) * 2).round(),
              onChanged: (v) => setDialogState(() => value = v),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(value),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
