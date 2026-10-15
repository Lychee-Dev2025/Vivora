import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../activity_monitoring/data/models/activity_date_utils.dart';
import '../../activity_monitoring/data/models/activity_sync_snapshot.dart';
import '../../activity_monitoring/data/models/app_usage_entry.dart';
import '../../activity_monitoring/data/models/daily_activity_log.dart';
import '../../activity_monitoring/data/repositories/activity_repository.dart';
import '../../activity_monitoring/data/services/activity_sync_service.dart';
import '../../behavior_analysis/domain/behavior_analysis_engine.dart';
import '../../behavior_analysis/domain/behavior_models.dart';
import '../../first_time_setup/data/models/user_profile_model.dart';
import '../../first_time_setup/data/services/user_profile_service.dart';
import '../../focus_mode/data/focus_session_repository.dart';
import '../../productivity_scoring/data/models/productivity_models.dart';
import '../../productivity_scoring/data/services/productivity_repository.dart';
import '../data/history_data.dart';
import 'recommendation_service.dart';

class InsightsSnapshot {
  const InsightsSnapshot({
    required this.history,
    required this.analyses,
    required this.recommendations,
    this.loadError,
  });

  final HistoryData history;

  /// Module 3 results for today, the last 7 and the last 30 days.
  final Map<AnalysisPeriod, BehaviorAnalysis> analyses;
  final List<Recommendation> recommendations;

  /// Set when some stored history could not be read (e.g. offline with an
  /// empty cache); the snapshot then only contains what was available.
  final String? loadError;

  BehaviorAnalysis analysis(AnalysisPeriod period) => analyses[period]!;
}

/// Read-only access to Module 3 results, for Module 6 and any other consumer.
abstract class BehaviorInsightsProvider {
  /// Latest analysis for [period], or null before the first load.
  BehaviorAnalysis? analysisFor(AnalysisPeriod period);

  /// Loads (or reuses cached) history and returns every period's analysis.
  Future<Map<AnalysisPeriod, BehaviorAnalysis>?> ensureAnalyses();

  /// Notifies when any analysis changes.
  Listenable get changes;
}

/// Where history comes from. [FirestoreInsightsSource] in the app; tests
/// substitute an in-memory source.
abstract class InsightsSource {
  /// Loads [days] local days of the user's records. Failures of individual
  /// parts are reported through [onPartialFailure] and yield empty parts.
  Future<HistoryData> load(
    String uid,
    DateTime now, {
    required int days,
    required void Function(String what) onPartialFailure,
  });

  /// Persists derived results (best effort).
  Future<void> store(
    String uid,
    DateTime now,
    Map<AnalysisPeriod, BehaviorAnalysis> analyses,
  );
}

/// Loads history once and shares it with the dashboard, analytics, reports,
/// goals, badges and (later) Module 6, so they all see the same numbers.
///
/// * Reloads when a productivity log or focus session is saved.
/// * Re-runs the analysis (no Firestore reads) when today's live device
///   capture changes.
/// * Drops everything when the signed-in user changes, so one account never
///   sees another's data.
/// * The engine is pure Dart and runs once per change, never in `build`.
class InsightsService implements BehaviorInsightsProvider {
  InsightsService({
    required InsightsSource source,
    required String? Function() currentUserId,
    Stream<String?>? userChanges,
    ValueListenable<TodayActivity?>? liveToday,
    List<Listenable> invalidators = const <Listenable>[],
    DateTime Function()? clock,
    this.engine = const BehaviorAnalysisEngine(),
  }) : _source = source,
       _currentUserId = currentUserId,
       _liveToday = liveToday,
       _clock = clock ?? DateTime.now {
    for (final Listenable l in invalidators) {
      l.addListener(_invalidate);
    }
    liveToday?.addListener(_onTodayChanged);
    userChanges?.listen(_onUserChanged);
  }

  static final InsightsService instance = InsightsService(
    source: FirestoreInsightsSource(),
    currentUserId: () => FirebaseAuth.instance.currentUser?.uid,
    userChanges: FirebaseAuth.instance.authStateChanges().map(
      (User? u) => u?.uid,
    ),
    liveToday: ActivitySyncService.instance.today,
    invalidators: <Listenable>[
      ProductivityRepository.revision,
      FocusSessionRepository.revision,
    ],
  );

  /// 30 days analysed + the previous 30 for comparison.
  static const int historyDays = 60;

  final InsightsSource _source;
  final String? Function() _currentUserId;
  final ValueListenable<TodayActivity?>? _liveToday;
  final DateTime Function() _clock;
  final BehaviorAnalysisEngine engine;
  final RecommendationService _recommendations = const RecommendationService();

  final ValueNotifier<InsightsSnapshot?> snapshot =
      ValueNotifier<InsightsSnapshot?>(null);
  final ValueNotifier<bool> loading = ValueNotifier<bool>(false);

  String? _uid;
  Future<InsightsSnapshot?>? _inFlight;
  bool _stale = true;

  @override
  Listenable get changes => snapshot;

  @override
  BehaviorAnalysis? analysisFor(AnalysisPeriod period) =>
      snapshot.value?.analyses[period];

  @override
  Future<Map<AnalysisPeriod, BehaviorAnalysis>?> ensureAnalyses() async =>
      (await ensureLoaded())?.analyses;

  void _onUserChanged(String? uid) {
    if (uid != _uid) {
      _uid = uid;
      _stale = true;
      snapshot.value = null;
    }
  }

  Future<InsightsSnapshot?> ensureLoaded() {
    _onUserChanged(_currentUserId());
    if (!_stale && snapshot.value != null) {
      return Future<InsightsSnapshot?>.value(snapshot.value);
    }
    return reload();
  }

  Future<InsightsSnapshot?> reload() {
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  void _invalidate() {
    _stale = true;
    if (snapshot.value != null) {
      unawaited(reload());
    }
  }

  void _onTodayChanged() {
    final InsightsSnapshot? current = snapshot.value;
    final TodayActivity? today = _liveToday?.value;
    if (current == null || today == null) {
      return;
    }
    snapshot.value = _compose(
      current.history.withToday(log: today.log, apps: today.apps),
      current.loadError,
    );
  }

  Future<InsightsSnapshot?> _load() async {
    final String? uid = _currentUserId();
    if (uid == null) {
      snapshot.value = null;
      return null;
    }
    loading.value = true;
    final DateTime now = _clock();
    final List<String> errors = <String>[];
    try {
      HistoryData history = await _source.load(
        uid,
        now,
        days: historyDays,
        onPartialFailure: errors.add,
      );
      final TodayActivity? live = _liveToday?.value;
      if (live != null && ActivityDateUtils.isSameDay(live.log.date, now)) {
        history = history.withToday(log: live.log, apps: live.apps);
      }
      // The account may have changed while loading: never publish the
      // previous user's data.
      if (uid != _currentUserId()) {
        return null;
      }
      final InsightsSnapshot result = _compose(
        history,
        errors.isEmpty
            ? null
            : 'Some history could not be loaded (${errors.toSet().join(', ')}).',
      );
      snapshot.value = result;
      _stale = false;
      unawaited(_source.store(uid, now, result.analyses));
      return result;
    } finally {
      loading.value = false;
    }
  }

  InsightsSnapshot _compose(HistoryData history, String? loadError) {
    final Map<AnalysisPeriod, BehaviorAnalysis> analyses = engine.analyzeAll(
      history,
      calculatedAt: _clock(),
    );
    return InsightsSnapshot(
      history: history,
      analyses: analyses,
      recommendations: _recommendations.generate(
        history: history,
        analysis: analyses[AnalysisPeriod.week]!,
      ),
      loadError: loadError,
    );
  }
}

/// Reads the existing collections under `users/{uid}`; adds nothing new
/// except overwriting the per-day `insights/{yyyy-MM-dd}` result document.
class FirestoreInsightsSource implements InsightsSource {
  FirestoreInsightsSource({
    ActivityRepository? activityRepository,
    ProductivityRepository? productivityRepository,
    FocusSessionRepository? focusRepository,
    UserProfileService? profileService,
  }) : _activity = activityRepository ?? ActivityRepository(),
       _scores = productivityRepository ?? ProductivityRepository(),
       _focus = focusRepository ?? FocusSessionRepository(),
       _profiles = profileService ?? UserProfileService();

  final ActivityRepository _activity;
  final ProductivityRepository _scores;
  final FocusSessionRepository _focus;
  final UserProfileService _profiles;

  static const Duration _timeout = Duration(seconds: 8);

  /// Days captured before compact app summaries existed fall back to the
  /// (icon-heavy) per-app documents, but only for this many recent days.
  static const int legacyAppDetailDays = 14;

  @override
  Future<HistoryData> load(
    String uid,
    DateTime now, {
    required int days,
    required void Function(String what) onPartialFailure,
  }) async {
    Future<T> guard<T>(Future<T> future, T fallback, String what) async {
      try {
        return await future.timeout(_timeout);
      } catch (error) {
        onPartialFailure(what);
        debugPrint('Insights: could not load $what: $error');
        return fallback;
      }
    }

    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      guard<List<DailyActivityLog>>(
        _activity.getActivityLogsForLastDays(uid: uid, days: days, today: now),
        const <DailyActivityLog>[],
        'activity history',
      ),
      guard<List<SavedDailyScore>>(
        _scores.getScoresForLastDays(uid, days: days, today: now),
        const <SavedDailyScore>[],
        'scores',
      ),
      guard<List<FocusSession>>(
        _focus.getRecent(uid, days: days),
        const <FocusSession>[],
        'focus sessions',
      ),
      guard<UserProfile?>(_profiles.getUserProfile(uid), null, 'profile'),
      guard<Map<String, AppCategory>>(
        _activity.getCategoryOverrides(uid: uid),
        const <String, AppCategory>{},
        'app categories',
      ),
    ]);

    final List<DailyActivityLog> logs = results[0]! as List<DailyActivityLog>;
    final String legacyFrom = ActivityDateUtils.dayKey(
      ActivityDateUtils.lastDays(now, legacyAppDetailDays).first,
    );
    final Map<String, List<AppUsageEntry>> appsByDay =
        <String, List<AppUsageEntry>>{};
    await Future.wait(
      logs
          .where(
            (l) =>
                l.appSummary == null &&
                ActivityDateUtils.dayKey(l.date).compareTo(legacyFrom) >= 0,
          )
          .map((DailyActivityLog log) async {
            appsByDay[ActivityDateUtils.dayKey(log.date)] = await guard(
              _activity.getDailyAppUsage(
                uid: uid,
                date: log.date,
                captureId: log.captureId,
              ),
              const <AppUsageEntry>[],
              'app usage',
            );
          }),
    );

    return HistoryData(
      today: now,
      activityLogs: logs,
      appUsageByDay: appsByDay,
      scores: results[1]! as List<SavedDailyScore>,
      focusSessions: results[2]! as List<FocusSession>,
      goals: (results[3] as UserProfile?)?.goals,
      categoryOverrides: results[4]! as Map<String, AppCategory>,
    );
  }

  /// One document per day, fully overwritten (no merge) so it never mixes
  /// results from different calculations. It is derived data: deleting it
  /// loses nothing, and it is recalculated on the next load.
  @override
  Future<void> store(
    String uid,
    DateTime now,
    Map<AnalysisPeriod, BehaviorAnalysis> analyses,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('insights')
          .doc(ActivityDateUtils.dayKey(now))
          .set(<String, dynamic>{
            'engine': 'behavior_analysis_v2',
            'generatedAt': FieldValue.serverTimestamp(),
            'week': analyses[AnalysisPeriod.week]!.toMap(),
            'month': analyses[AnalysisPeriod.month]!.toMap(),
          })
          .timeout(_timeout);
    } catch (error) {
      debugPrint('Insights not stored yet: $error');
    }
  }
}
