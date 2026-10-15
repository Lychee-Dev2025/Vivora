import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/info_card.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../domain/behavior_models.dart';
import '../domain/behavior_stats.dart';

/// Analytics → "Patterns & Habits": Module 3 results for a selectable period.
///
/// Purely presentational: every number comes from [BehaviorAnalysis]; nothing
/// is computed here except formatting.
class BehaviorInsightsSection extends StatefulWidget {
  const BehaviorInsightsSection({
    super.key,
    required this.analyses,
    this.initialPeriod = AnalysisPeriod.week,
  });

  /// Null while loading.
  final Map<AnalysisPeriod, BehaviorAnalysis>? analyses;
  final AnalysisPeriod initialPeriod;

  @override
  State<BehaviorInsightsSection> createState() =>
      _BehaviorInsightsSectionState();
}

class _BehaviorInsightsSectionState extends State<BehaviorInsightsSection> {
  late AnalysisPeriod _period = widget.initialPeriod;

  @override
  Widget build(BuildContext context) {
    final Map<AnalysisPeriod, BehaviorAnalysis>? analyses = widget.analyses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final AnalysisPeriod p in AnalysisPeriod.values)
              ChoiceChip(
                label: Text(p.label),
                selected: _period == p,
                onSelected: (_) => setState(() => _period = p),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (analyses == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          )
        else
          _PeriodView(analysis: analyses[_period]!),
      ],
    );
  }
}

class _PeriodView extends StatelessWidget {
  const _PeriodView({required this.analysis});

  final BehaviorAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final DataQualityReport q = analysis.dataQuality;
    final bool multiDay = analysis.period != AnalysisPeriod.day;
    final List<TrendResult> trends = analysis.trends.values
        .where((t) => t.direction != TrendDirection.insufficientData)
        .where((t) => _trendLabels.containsKey(t.metric))
        .toList();
    final List<GoalAchievement> goals = analysis.goals
        .where((g) => g.observedDays > 0 && g.goal != 'loggedScreenLimit')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _DataAvailability(analysis: analysis),
        const SizedBox(height: 12),
        if (!analysis.hasAnyData)
          const _Empty(
            'Keep logging your activities to unlock behavior insights. '
            'Patterns appear once Vivora has a few days of logs or measured phone usage.',
          )
        else if (analysis.habits.isEmpty)
          _Empty(
            multiDay
                ? 'No recurring patterns yet in this period. Patterns need at least 3 days of the same kind of data '
                      '(logged ${q.loggedDays}, measured ${q.measuredDays} of ${q.periodDays} days so far).'
                : 'Nothing recorded for today yet.',
          )
        else
          for (final DetectedHabit h in analysis.habits)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: HabitCard(habit: h),
            ),
        if (multiDay && trends.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          _Block(
            title: 'Trends',
            subtitle:
                trends.first.basis == 'previous ${analysis.period.days} days'
                ? 'Compared with the previous ${analysis.period.days} days'
                : 'Compared within the period',
            children: <Widget>[
              for (final TrendResult t in trends) _TrendRow(trend: t),
            ],
          ),
        ],
        if (goals.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _Block(
            title: 'Goal achievement',
            children: <Widget>[
              for (final GoalAchievement g in goals) _GoalRow(goal: g),
            ],
          ),
        ],
        if (multiDay && analysis.relationships.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          _Block(
            title: 'Links with your productivity score',
            subtitle: 'Associations on the same days, not causes.',
            children: <Widget>[
              for (final BehaviorRelationship r in analysis.relationships)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    r.statement,
                    style: TextStyle(
                      color: r.isConclusive
                          ? context.palette.textPrimary
                          : context.palette.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        _Limitations(quality: q),
      ],
    );
  }
}

const Map<String, String> _trendLabels = <String, String>{
  'appUsageMinutes': 'Measured app usage',
  'distractingAppMinutes': 'Distracting app time',
  'productiveAppMinutes': 'Productive app time',
  'unlocks': 'Phone unlocks',
  'studyHours': 'Logged study',
  'deepFocusHours': 'Logged deep focus',
  'focusSessionMinutes': 'Focus Mode time',
  'sleepHours': 'Logged sleep',
  'routineRating': 'Routine rating',
  'activityRating': 'Activity rating',
  'score': 'Productivity score',
};

String _formatValue(double v, String unit) => switch (unit) {
  'minutes' => formatMinutes(v.round()),
  'hours' => formatMinutes((v * 60).round()),
  'rating' => '${v.round()}%',
  'points' => '${v.round()}',
  _ => v.round().toString(),
};

String sourceLabel(DataSource s) => switch (s) {
  DataSource.measured => 'Measured by phone',
  DataSource.tracked => 'Focus Mode',
  DataSource.selfReported => 'Your log',
  DataSource.mixed => 'Log + scoring',
};

class _DataAvailability extends StatelessWidget {
  const _DataAvailability({required this.analysis});
  final BehaviorAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final DataQualityReport q = analysis.dataQuality;
    final String streak = analysis.loggingStreak == 0
        ? 'No current logging streak'
        : 'Logging streak: ${analysis.loggingStreak} day${analysis.loggingStreak == 1 ? '' : 's'}';
    return Text(
      '${analysis.period.label}: logged ${q.loggedDays} of ${q.periodDays} days · '
      'measured ${q.measuredDays} of ${q.periodDays} days · $streak'
      '${analysis.bestLoggingStreak > analysis.loggingStreak ? ' (best ${analysis.bestLoggingStreak})' : ''}.',
      style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
    );
  }
}

/// One detected habit / pattern / observation.
class HabitCard extends StatelessWidget {
  const HabitCard({super.key, required this.habit});

  final DetectedHabit habit;

  @override
  Widget build(BuildContext context) {
    final (String status, Color color) = switch (habit.polarity) {
      InsightPolarity.positive => ('Positive', context.palette.success),
      InsightPolarity.negative => ('Needs attention', context.palette.warning),
      InsightPolarity.informational => ('Info', context.brand),
    };
    final String quality = habit.isSingleDayObservation
        ? 'Single day'
        : switch (habit.quality) {
            EvidenceQuality.strong => 'Strong evidence',
            EvidenceQuality.moderate => 'Moderate evidence',
            EvidenceQuality.limited => 'Limited evidence',
          };
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            habit.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _Chip(status, color),
              _Chip(quality, context.palette.textSecondary),
              _Chip(sourceLabel(habit.source), AppColors.softPurple),
            ],
          ),
          const SizedBox(height: 8),
          Text(habit.description),
          for (final String e in habit.evidence) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '• $e',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${habit.period.label} · ${habit.sampleSize} day${habit.sampleSize == 1 ? '' : 's'} of data',
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tinted label with a colour dot. The text itself uses the primary text
/// colour so it stays readable (≥ 4.5:1) whatever the accent.
class _Chip extends StatelessWidget {
  const _Chip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: context.palette.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.children, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({required this.trend});
  final TrendResult trend;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String word) = switch (trend.direction) {
      TrendDirection.increasing => (Icons.trending_up_rounded, 'Up'),
      TrendDirection.decreasing => (Icons.trending_down_rounded, 'Down'),
      _ => (Icons.trending_flat_rounded, 'Stable'),
    };
    final String change = trend.changeRatio == null
        ? ''
        : ' ${BehaviorStats.percent(trend.changeRatio!)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20, color: context.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_trendLabels[trend.metric]}: $word$change '
              '(${_formatValue(trend.currentMean!, trend.unit)} vs ${_formatValue(trend.previousMean!, trend.unit)})',
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.goal});
  final GoalAchievement goal;

  @override
  Widget build(BuildContext context) {
    final String name = switch (goal.goal) {
      'sleep' => 'Sleep goal',
      'study' => 'Study goal',
      'focus' => 'Deep focus goal',
      _ => 'Screen-time limit (measured)',
    };
    final String verb = goal.isLimit ? 'kept' : 'met';
    final String kind = goal.source == DataSource.measured
        ? 'measured'
        : 'logged';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '$name: $verb on ${goal.metDays} of ${goal.observedDays} $kind days',
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.hourglass_empty_rounded, color: context.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: context.palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Limitations extends StatelessWidget {
  const _Limitations({required this.quality});
  final DataQualityReport quality;

  @override
  Widget build(BuildContext context) {
    final List<String> notes = <String>[
      ...quality.missing.values,
      ...quality.warnings,
      if (quality.excludedTotal > 0)
        '${quality.excludedTotal} invalid or duplicate record${quality.excludedTotal == 1 ? ' was' : 's were'} left out of the analysis.',
    ];
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text(
          'What this analysis cannot tell',
          style: TextStyle(fontSize: 14),
        ),
        children: <Widget>[
          for (final String n in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '• $n',
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
