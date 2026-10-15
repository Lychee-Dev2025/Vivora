import 'package:animate_do/animate_do.dart';
import 'package:vivora/core/services/session.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/utils/friendly_error.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import 'package:vivora/core/widgets/app_bar_title.dart';
import 'package:vivora/core/theme/app_colors.dart';
import 'package:vivora/core/utils/slider_value.dart';
import 'package:vivora/core/widgets/gradient_background.dart';
import 'package:vivora/core/widgets/primary_button.dart';
import 'package:vivora/features/activity_monitoring/data/models/activity_sync_snapshot.dart';
import 'package:vivora/features/activity_monitoring/data/services/activity_sync_service.dart';
import 'package:vivora/features/first_time_setup/data/models/user_profile_model.dart';
import 'package:vivora/features/first_time_setup/data/services/user_profile_service.dart';
import 'package:vivora/features/focus_mode/data/focus_session_repository.dart';
import 'package:vivora/features/productivity_scoring/data/models/productivity_models.dart';
import 'package:vivora/features/productivity_scoring/data/services/productivity_repository.dart';
import 'package:vivora/features/productivity_scoring/data/services/productivity_score_service.dart';

/// Records today's inputs. Every metric starts as "not recorded" unless it can
/// be prefilled from real data (today's saved log, Android usage, Focus Mode).
class DailyProductivityEntryScreen extends StatefulWidget {
  const DailyProductivityEntryScreen({super.key});

  @override
  State<DailyProductivityEntryScreen> createState() =>
      _DailyProductivityEntryScreenState();
}

class _DailyProductivityEntryScreenState
    extends State<DailyProductivityEntryScreen> {
  final _scoreService = ProductivityScoreService();
  final _repository = ProductivityRepository();
  final _profileService = UserProfileService();
  final _focusRepository = FocusSessionRepository();
  final _activityService = ActivitySyncService.instance;

  bool _isLoading = false;
  bool _isPrefilling = true;
  UserProfile? _profile;

  double? _sleepHours;
  double? _studyHours;
  double? _focusHours;
  double? _screenTime;
  double? _consistency;
  double? _activity;

  double? _deviceScreenHours;
  int? _measuredActiveMinutes;
  int? _focusSessionMinutes;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final String? uid = Session.currentUserId();
    final DateTime today = DateTime.now();
    final TodayActivity? activity = _activityService.today.value;
    if (activity != null) {
      final int? appMinutes = activity.log.appUsageMinutes;
      if (appMinutes != null) {
        _deviceScreenHours = appMinutes / 60;
      }
      _measuredActiveMinutes = activity.log.activeMinutes;
    }

    if (uid != null) {
      try {
        final results = await Future.wait<Object?>(<Future<Object?>>[
          _profileService.getUserProfile(uid),
          _repository.getDailyLog(uid, today),
          _focusRepository.focusedMinutesOn(uid, today),
        ]).timeout(const Duration(seconds: 8));
        _profile = results[0] as UserProfile?;
        final DailyProductivityLog? existing =
            results[1] as DailyProductivityLog?;
        _focusSessionMinutes = results[2] as int?;
        if (existing != null) {
          _sleepHours = existing.actualSleepHours;
          _studyHours = existing.actualStudyHours;
          _focusHours = existing.actualFocusHours;
          _screenTime = existing.actualScreenTimeHours;
          _consistency = existing.consistencyScore;
          _activity = existing.activityScore;
        }
      } catch (error) {
        debugPrint('Prefill failed: $error');
      }
    }

    // Device screen time is the measured value; it replaces a previously saved
    // device value but never a value the user typed in themselves.
    _screenTime ??= _deviceScreenHours;
    if (_focusHours == null && (_focusSessionMinutes ?? 0) > 0) {
      _focusHours = _focusSessionMinutes! / 60;
    }

    if (mounted) {
      setState(() => _isPrefilling = false);
    }
  }

  DailyProductivityLog _buildLog() {
    return DailyProductivityLog(
      date: DateTime.now(),
      actualSleepHours: _sleepHours,
      actualStudyHours: _studyHours,
      actualFocusHours: _focusHours,
      actualScreenTimeHours: _screenTime,
      screenTimeFromDevice:
          _screenTime != null &&
          _deviceScreenHours != null &&
          (_screenTime! - _deviceScreenHours!).abs() < 0.01,
      consistencyScore: _consistency,
      activityScore: _activity,
      measuredActiveMinutes: _measuredActiveMinutes,
      focusSessionMinutes: _focusSessionMinutes,
    );
  }

  Future<void> _saveEntry() async {
    final String? uid = Session.currentUserId();
    if (uid == null) {
      _showMessage('Please sign in again.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final UserProfile? profile =
          _profile ?? await _profileService.getUserProfile(uid);
      if (profile == null) {
        throw Exception('Profile not found. Please complete setup first.');
      }
      final log = _buildLog();
      final result = _scoreService.calculateScore(log: log, profile: profile);
      if (result.overallScore == null) {
        _showMessage(
          'Record at least one metric before saving.',
          isError: true,
        );
        return;
      }
      final SaveOutcome outcome = await _repository.saveDailyLog(
        uid: uid,
        log: log,
        result: result,
      );
      if (!mounted) {
        return;
      }
      _showMessage(
        outcome == SaveOutcome.synced
            ? 'Saved. Score: ${result.overallScore!.round()}'
            : 'Saved on this device (score ${result.overallScore!.round()}). It will upload when you are online.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage(
        friendlyError(error, action: 'save your log'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        // Success uses the theme snackbar colours (readable in both themes).
        backgroundColor: isError ? context.palette.danger : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProductivityScoreResult? preview = _profile == null
        ? null
        : _scoreService.calculateScore(log: _buildLog(), profile: _profile!);

    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle('Log Today\'s Progress'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.palette.textPrimary),
      ),
      extendBodyBehindAppBar: true,
      body: GradientBackground(
        child: _isPrefilling
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  20,
                  kToolbarHeight + 20,
                  20,
                  30,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInDown(
                      child: Text(
                        'How was your day?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: context.palette.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Set the metrics you want to record. Anything left as "Not recorded" is excluded from the score instead of counted as zero.',
                      style: TextStyle(color: context.palette.textSecondary),
                    ),
                    if (_deviceScreenHours != null ||
                        (_focusSessionMinutes ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      _InfoBanner(
                        text: [
                          if (_deviceScreenHours != null)
                            'Logged screen time starts from your measured app usage so far today; you can change it.',
                          if ((_focusSessionMinutes ?? 0) > 0)
                            'Focus Mode recorded $_focusSessionMinutes min today.',
                          if (_measuredActiveMinutes != null)
                            'Movement sensor: $_measuredActiveMinutes active min.',
                        ].join(' '),
                      ),
                    ],
                    const SizedBox(height: 24),
                    _buildSliderCard(
                      title: 'Sleep Duration',
                      value: _sleepHours,
                      suffix: 'h',
                      icon: Icons.nightlight_round,
                      max: 12,
                      divisions: 48,
                      initial: 7,
                      onChanged: (val) => setState(() => _sleepHours = val),
                      color: context.brand,
                    ),
                    _buildSliderCard(
                      title: 'Study Time',
                      value: _studyHours,
                      suffix: 'h',
                      icon: Icons.menu_book_rounded,
                      max: 16,
                      divisions: 64,
                      initial: 2,
                      onChanged: (val) => setState(() => _studyHours = val),
                      color: AppColors.softPurple,
                    ),
                    _buildSliderCard(
                      title: 'Deep Focus Time',
                      value: _focusHours,
                      suffix: 'h',
                      icon: Icons.timer_rounded,
                      max: 12,
                      divisions: 48,
                      initial: 1,
                      onChanged: (val) => setState(() => _focusHours = val),
                      color: AppColors.accentGreen,
                    ),
                    _buildSliderCard(
                      title: 'Logged Screen Time',
                      value: _screenTime,
                      suffix: 'h',
                      icon: Icons.phone_iphone_rounded,
                      max: 18,
                      divisions: 72,
                      initial: _deviceScreenHours ?? 3,
                      onChanged: (val) => setState(() => _screenTime = val),
                      color: Colors.orange,
                    ),
                    _buildSliderCard(
                      title: 'Routine Consistency',
                      subtitle:
                          'How closely did you follow your planned routine?',
                      value: _consistency,
                      suffix: '%',
                      icon: Icons.repeat_rounded,
                      max: 100,
                      divisions: 20,
                      initial: 50,
                      onChanged: (val) => setState(() => _consistency = val),
                      color: AppColors.secondaryCyan,
                    ),
                    _buildSliderCard(
                      title: 'Physical Activity',
                      subtitle: _measuredActiveMinutes == null
                          ? 'Rate how active you were today.'
                          : 'Leave unrated to use the $_measuredActiveMinutes measured active minutes.',
                      value: _activity,
                      suffix: '%',
                      icon: Icons.directions_run_rounded,
                      max: 100,
                      divisions: 20,
                      initial: 50,
                      onChanged: (val) => setState(() => _activity = val),
                      color: Colors.pinkAccent,
                    ),
                    if (preview != null) ScorePreviewCard(result: preview),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Calculate & Save Score',
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _saveEntry,
                      icon: Icons.calculate_rounded,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSliderCard({
    required String title,
    String? subtitle,
    required double? value,
    required String suffix,
    required IconData icon,
    required double max,
    required int divisions,
    required double initial,
    required ValueChanged<double?> onChanged,
    required Color color,
  }) {
    final bool recorded = value != null;
    final String valueText = !recorded
        ? 'Not recorded'
        : suffix == 'h'
        ? _hours(value)
        : '${value.round()}$suffix';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.palette.shadow.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  valueText,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: recorded ? 16 : 13,
                    fontWeight: FontWeight.w800,
                    color: recorded
                        ? context.palette.textPrimary
                        : context.palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (recorded)
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: color,
                      inactiveTrackColor: color.withValues(alpha: 0.1),
                      thumbColor: color,
                      overlayColor: color.withValues(alpha: 0.2),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: normalizeSliderValue(value, min: 0, max: max),
                      min: 0,
                      max: max,
                      divisions: divisions,
                      onChanged: onChanged,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: context.palette.textSecondary,
                  onPressed: () => onChanged(null),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () =>
                    onChanged(normalizeSliderValue(initial, min: 0, max: max)),
                icon: Icon(Icons.add_circle_outline_rounded, color: color),
                label: Text('Record', style: TextStyle(color: color)),
              ),
            ),
        ],
      ),
    );
  }

  String _hours(double hours) {
    final int minutes = (hours * 60).round();
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: context.palette.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class ScorePreviewCard extends StatelessWidget {
  const ScorePreviewCard({super.key, required this.result});
  final ProductivityScoreResult result;

  @override
  Widget build(BuildContext context) {
    final double? score = result.overallScore;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.brand.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            score == null
                ? 'Score preview: not enough data'
                : 'Score preview: ${score.round()} / 100',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          for (final ScoreComponent c in result.components)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 132,
                    child: Text(
                      '${c.label} (${(c.weight * 100).round()}%)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      c.isAvailable
                          ? '${c.score!.round()} · ${c.detail}'
                          : 'Excluded · ${c.detail}',
                      style: TextStyle(
                        fontSize: 13,
                        color: c.isAvailable
                            ? context.palette.textPrimary
                            : context.palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (result.isPartial && score != null)
            Text(
              'Partial score: based on ${(result.coverage * 100).round()}% of the weighted metrics.',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}
