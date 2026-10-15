import 'dart:async';

import 'package:vivora/core/services/session.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';
import 'package:vivora/core/widgets/app_bar_title.dart';

import '../../../core/widgets/gradient_background.dart';
import '../../../core/widgets/info_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../../analytics/data/analytics_calculator.dart';
import '../data/focus_session_repository.dart';

/// Pomodoro-style focus timer. Elapsed time is computed from wall-clock
/// timestamps (not by counting ticks), so it stays correct if the app is
/// briefly backgrounded. A stopped session is saved with the time actually
/// focused; sessions under one minute are discarded.
class FocusModeScreen extends StatefulWidget {
  const FocusModeScreen({super.key, this.repository});

  final FocusSessionRepository? repository;

  @override
  State<FocusModeScreen> createState() => _FocusModeScreenState();
}

enum _TimerState { ready, running, paused }

class _FocusModeScreenState extends State<FocusModeScreen> {
  static const List<int> durations = <int>[15, 25, 50];

  late final FocusSessionRepository _repository =
      widget.repository ?? FocusSessionRepository();

  int _plannedMinutes = 25;
  _TimerState _state = _TimerState.ready;
  DateTime? _startedAt;
  DateTime? _runningSince;
  Duration _accumulated = Duration.zero;
  Timer? _ticker;

  List<FocusSession> _history = const <FocusSession>[];
  bool _loadingHistory = true;
  String? _historyError;

  Duration get _elapsed {
    final DateTime? since = _runningSince;
    return since == null
        ? _accumulated
        : _accumulated + DateTime.now().difference(since);
  }

  Duration get _remaining {
    final Duration left = Duration(minutes: _plannedMinutes) - _elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final String? uid = Session.currentUserId();
    if (uid == null) {
      setState(() => _loadingHistory = false);
      return;
    }
    try {
      final sessions = await _repository
          .getRecent(uid, days: 7)
          .timeout(const Duration(seconds: 8));
      if (mounted) setState(() => _history = sessions);
    } catch (error) {
      if (mounted) {
        setState(() => _historyError = 'History unavailable offline.');
      }
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _start() {
    final DateTime now = DateTime.now();
    setState(() {
      _state = _TimerState.running;
      _startedAt ??= now;
      _runningSince = now;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining == Duration.zero) {
        _finish(completed: true);
      } else {
        setState(() {});
      }
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() {
      _accumulated = _elapsed;
      _runningSince = null;
      _state = _TimerState.paused;
    });
  }

  Future<void> _finish({required bool completed}) async {
    _ticker?.cancel();
    final Duration focused = completed
        ? Duration(minutes: _plannedMinutes)
        : _elapsed;
    final DateTime? startedAt = _startedAt;
    setState(() {
      _state = _TimerState.ready;
      _startedAt = null;
      _runningSince = null;
      _accumulated = Duration.zero;
    });
    if (startedAt == null) return;
    if (focused.inSeconds < 60) {
      _snack('Session shorter than a minute; not saved.');
      return;
    }
    final String? uid = Session.currentUserId();
    if (uid == null) {
      _snack('Sign in to save focus sessions.');
      return;
    }
    final session = FocusSession(
      startedAt: startedAt,
      endedAt: DateTime.now(),
      plannedMinutes: _plannedMinutes,
      focusedSeconds: focused.inSeconds,
      completed: completed,
    );
    await _repository.save(uid, session);
    if (!mounted) return;
    setState(() => _history = <FocusSession>[session, ..._history]);
    _snack(
      completed
          ? 'Session complete: ${formatMinutes(session.focusedMinutes)} saved.'
          : 'Session stopped: ${formatMinutes(session.focusedMinutes)} saved.',
    );
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _clock(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool idle = _state == _TimerState.ready;
    return PopScope(
      canPop: idle,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool? stop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('Leave Focus Mode?'),
            content: const Text(
              'The session will be stopped and the time so far saved.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Keep going'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Stop & leave'),
              ),
            ],
          ),
        );
        if (stop == true && mounted) {
          await _finish(completed: false);
          if (mounted) Navigator.of(this.context).pop();
        }
      },
      child: _buildScaffold(context, idle),
    );
  }

  Widget _buildScaffold(BuildContext context, bool idle) {
    return Scaffold(
      appBar: AppBar(title: const AppBarTitle('Focus Mode')),
      body: GradientBackground(
        child: ListView(
          children: <Widget>[
            Text(
              'Deep Focus Session',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Completed time is added to your daily log as focus time.',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final int minutes in durations)
                  ChoiceChip(
                    label: Text('$minutes min'),
                    selected: _plannedMinutes == minutes,
                    onSelected: idle
                        ? (_) => setState(() => _plannedMinutes = minutes)
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            InfoCard(
              gradient: context.palette.highlightGradient,
              child: Column(
                children: <Widget>[
                  Text(
                    switch (_state) {
                      _TimerState.ready => 'Ready to Focus',
                      _TimerState.running => 'Session Running',
                      _TimerState.paused => 'Paused',
                    },
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.palette.onHighlight,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _clock(
                      idle ? Duration(minutes: _plannedMinutes) : _remaining,
                    ),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: context.palette.onHighlight,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: idle
                        ? 0
                        : _elapsed.inSeconds / (_plannedMinutes * 60),
                    backgroundColor: context.palette.onHighlight.withValues(
                      alpha: 0.25,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.palette.onHighlight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_state == _TimerState.running)
              PrimaryButton(
                label: 'Pause',
                icon: Icons.pause_rounded,
                onPressed: _pause,
              )
            else
              PrimaryButton(
                label: _state == _TimerState.paused
                    ? 'Resume'
                    : 'Start Focus Session',
                icon: Icons.play_arrow_rounded,
                onPressed: _start,
              ),
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Stop & Save',
              expanded: true,
              onPressed: idle ? null : () => _finish(completed: false),
            ),
            const SizedBox(height: 18),
            InfoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Session History (7 days)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  if (_loadingHistory)
                    const LinearProgressIndicator()
                  else if (_history.isEmpty)
                    Text(
                      _historyError ?? 'No sessions yet. Start one above.',
                      style: TextStyle(color: context.palette.textSecondary),
                    )
                  else
                    for (final FocusSession s in _history.take(10))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${AnalyticsCalculator.formatDate(s.startedAt)}  ·  '
                          '${formatMinutes(s.focusedMinutes)} of ${s.plannedMinutes}m'
                          '${s.completed ? '  ✓' : ''}',
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
