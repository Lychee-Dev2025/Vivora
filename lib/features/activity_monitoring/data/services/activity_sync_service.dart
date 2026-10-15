import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;

import '../models/activity_date_utils.dart';
import '../models/activity_sync_snapshot.dart';
import '../models/activity_sync_state.dart';
import '../models/app_usage_entry.dart';
import '../models/daily_activity_log.dart';
import '../repositories/activity_repository.dart';
import 'android_activity_bridge.dart';
import 'app_category_service.dart';

/// Single source of truth for today's automatically collected data.
///
/// Flow of one sync:
///  1. read permissions;
///  2. capture the current local day from Android (recomputed from scratch, so
///     repeating it can never inflate totals);
///  3. apply the user's category overrides;
///  4. publish the result locally ([today]) so every screen shows the same
///     snapshot immediately, online or not;
///  5. upload to Firestore and report [cloudStatus] honestly: `synced` only
///     after the server acknowledged the write.
class ActivitySyncService {
  ActivitySyncService({
    required ActivityDataSource dataSource,
    required ActivityRepository repository,
    required String? Function() currentUserId,
    AppCategoryService categoryService = const AppCategoryService(),
    DateTime Function()? clock,
    this.cloudAckTimeout = const Duration(seconds: 15),
    this.readTimeout = const Duration(seconds: 6),
  }) : _dataSource = dataSource,
       _repository = repository,
       _currentUserId = currentUserId,
       _categoryService = categoryService,
       _clock = clock ?? DateTime.now;

  static final ActivitySyncService instance = ActivitySyncService(
    dataSource: AndroidActivityBridge.instance,
    repository: ActivityRepository(),
    currentUserId: () => FirebaseAuth.instance.currentUser?.uid,
  );

  final ActivityDataSource _dataSource;
  final ActivityRepository _repository;
  final String? Function() _currentUserId;
  final AppCategoryService _categoryService;
  final DateTime Function() _clock;
  final Duration cloudAckTimeout;
  final Duration readTimeout;

  /// Minimum gap between automatic (non-forced) captures.
  static const Duration throttleWindow = Duration(minutes: 2);

  final ValueNotifier<ActivitySyncState> syncState =
      ValueNotifier<ActivitySyncState>(ActivitySyncState.idle);
  final ValueNotifier<ActivityPermissionSnapshot> permissions =
      ValueNotifier<ActivityPermissionSnapshot>(
        ActivityPermissionSnapshot.unknown,
      );
  final ValueNotifier<TodayActivity?> today = ValueNotifier<TodayActivity?>(
    null,
  );
  final ValueNotifier<CloudSyncStatus> cloudStatus =
      ValueNotifier<CloudSyncStatus>(CloudSyncStatus.idle);
  final ValueNotifier<ActivitySyncResult?> latestResult =
      ValueNotifier<ActivitySyncResult?>(null);

  Future<ActivitySyncResult>? _inFlight;
  String? _uid;
  DateTime? _lastCaptureAt;
  Map<String, AppCategory>? _overrides;
  String? _latestCaptureId;

  Future<ActivityPermissionSnapshot> refreshPermissions() async {
    final ActivityPermissionSnapshot snapshot = await _dataSource
        .getPermissionSnapshot();
    permissions.value = snapshot;
    return snapshot;
  }

  Future<ActivityPermissionSnapshot> getPermissionSnapshot() =>
      refreshPermissions();

  Future<void> openUsageAccessSettings() =>
      _dataSource.openUsageAccessSettings();

  Future<bool> requestActivityPermission() async {
    final bool granted = await _dataSource.requestActivityPermission();
    if (granted) {
      await _dataSource.scheduleBackgroundSync();
    }
    await refreshPermissions();
    return granted;
  }

  /// Clears everything held for the previous account. Called on sign-in/out so
  /// one user can never see another user's data.
  void onUserChanged(String? uid) {
    if (uid == _uid) {
      return;
    }
    _uid = uid;
    _overrides = null;
    _lastCaptureAt = null;
    _latestCaptureId = null;
    today.value = null;
    latestResult.value = null;
    cloudStatus.value = CloudSyncStatus.idle;
    syncState.value = ActivitySyncState.idle;
  }

  /// Automatic sync (start-up, resume, screen open): throttled.
  Future<ActivitySyncResult> syncIfNeeded() => syncNow(force: false);

  /// Concurrent callers share the in-flight sync instead of starting another.
  Future<ActivitySyncResult> syncNow({bool force = false}) {
    final Future<ActivitySyncResult>? running = _inFlight;
    if (running != null) {
      return running;
    }
    final Future<ActivitySyncResult> future = _sync(force: force);
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<ActivitySyncResult> _sync({required bool force}) async {
    final String? uid = _currentUserId();
    if (uid == null) {
      onUserChanged(null);
      return _publish(
        ActivitySyncState.failed,
        'Sign in to collect activity data.',
      );
    }
    onUserChanged(uid);

    final DateTime now = _clock();
    final TodayActivity? current = today.value;
    if (!force &&
        current != null &&
        _lastCaptureAt != null &&
        now.difference(_lastCaptureAt!) < throttleWindow &&
        ActivityDateUtils.isSameDay(current.log.date, now)) {
      return latestResult.value ??
          _publish(syncState.value, 'Up to date.', today: current);
    }

    syncState.value = ActivitySyncState.syncing;
    try {
      final ActivityPermissionSnapshot snapshot = await refreshPermissions();
      if (!snapshot.usageAccessGranted) {
        // Nothing can be measured; still show what the cloud has for today.
        unawaited(_loadCachedToday(uid, now));
        return _publish(
          ActivitySyncState.permissionRequired,
          'Usage Access is required to measure screen time and app usage.',
        );
      }

      final ActivityDateRange day = ActivityDateUtils.currentDayRange(now);
      final ActivityCaptureSnapshot capture = await _dataSource
          .captureActivityRange(start: day.start, end: day.end);
      if (_uid != uid) {
        // The account changed while the device was being read.
        return _publish(ActivitySyncState.idle, 'Account changed.');
      }
      if (!capture.usagePermissionGranted) {
        return _publish(
          ActivitySyncState.permissionRequired,
          'Usage Access is required to measure screen time and app usage.',
        );
      }

      final Map<String, AppCategory> overrides = await _loadOverrides(uid);
      final List<AppUsageEntry> apps = _categoryService.categorizeEntries(
        capture.appUsageEntries,
        overrides: overrides,
      )..sort((a, b) => b.foregroundDuration.compareTo(a.foregroundDuration));

      final ActivitySyncMetadata metadata = await _dataSource.getSyncMetadata();
      final String captureId = now.millisecondsSinceEpoch.toString();
      final DailyActivityLog log = buildDailyLog(
        capture: capture,
        apps: apps,
        date: day.start,
        captureId: captureId,
        syncedAt: now,
        collectionStartedAt: metadata.collectionStartedAt ?? now,
      );

      final TodayActivity todayActivity = TodayActivity(log: log, apps: apps);
      today.value = todayActivity;
      _lastCaptureAt = now;
      _latestCaptureId = captureId;

      await _dataSource.saveSyncMetadata(
        metadata.copyWith(
          lastSuccessfulActivitySync: now,
          lastUsagePermissionState: snapshot.usageAccessGranted,
          lastActivityPermissionState: snapshot.activityPermissionGranted,
          collectionStartedAt: metadata.collectionStartedAt ?? now,
          lastSyncedUserId: uid,
        ),
      );
      if (snapshot.activityPermissionGranted &&
          !snapshot.backgroundSyncEnabled) {
        await _dataSource.scheduleBackgroundSync();
        await refreshPermissions();
      }

      final ActivitySyncState state = log.hasMovementData
          ? ActivitySyncState.success
          : ActivitySyncState.partialData;
      final ActivitySyncResult result = _publish(
        state,
        state == ActivitySyncState.success
            ? 'Device data collected.'
            : 'Screen and app data collected. Movement data is unavailable.',
        today: todayActivity,
      );

      await _upload(uid, todayActivity);
      return result;
    } on PlatformException catch (error) {
      return _publish(
        ActivitySyncState.failed,
        'Android activity bridge error: ${error.message ?? error.code}',
      );
    } catch (error) {
      debugPrint('Activity sync failed: $error');
      return _publish(
        ActivitySyncState.failed,
        'Could not read activity from this phone. Please try again.',
      );
    }
  }

  /// Builds the daily log from a capture. Category totals are summed from exact
  /// durations and rounded once, so they agree with the per-app list.
  static DailyActivityLog buildDailyLog({
    required ActivityCaptureSnapshot capture,
    required List<AppUsageEntry> apps,
    required DateTime date,
    required String captureId,
    required DateTime syncedAt,
    DateTime? collectionStartedAt,
  }) {
    int minutesFor(AppCategory category) {
      final int millis = apps
          .where((AppUsageEntry entry) => entry.category == category)
          .fold<int>(
            0,
            (int sum, AppUsageEntry entry) =>
                sum + entry.foregroundDuration.inMilliseconds,
          );
      return (millis / 60000).round();
    }

    return DailyActivityLog(
      date: ActivityDateUtils.dayStart(date),
      screenTimeMinutes: capture.screenTimeMinutes,
      appUsageMinutes: capture.appUsageMinutes,
      interactiveScreenTimeSeconds: capture.interactiveScreenTimeSeconds,
      phoneUnlockCount: capture.phoneUnlockCount,
      screenOnCount: capture.screenOnCount,
      screenOffCount: capture.screenOffCount,
      productiveAppMinutes: minutesFor(AppCategory.productive),
      distractingAppMinutes: minutesFor(AppCategory.distracting),
      neutralAppMinutes: minutesFor(AppCategory.neutral),
      uncategorizedAppMinutes: minutesFor(AppCategory.uncategorized),
      walkingMinutes: capture.walkingMinutes,
      runningMinutes: capture.runningMinutes,
      stillMinutes: capture.stillMinutes,
      vehicleMinutes: capture.vehicleMinutes,
      unknownActivityMinutes: capture.unknownActivityMinutes,
      movementStatus: capture.movementStatus,
      captureId: captureId,
      lastSyncAt: syncedAt,
      collectionStartedAt: collectionStartedAt,
      usagePermissionGranted: capture.usagePermissionGranted,
      activityPermissionGranted: capture.activityPermissionGranted,
      notificationPermissionGranted: capture.notificationPermissionGranted,
      source: capture.source,
      syncStatus: capture.syncStatus,
      appSummary: apps,
    );
  }

  Future<void> _upload(String uid, TodayActivity data) async {
    final String? captureId = data.log.captureId;
    cloudStatus.value = CloudSyncStatus(CloudSyncState.uploading, at: _clock());
    final Future<void> write = _repository.upsertDailyActivityLog(
      uid: uid,
      log: data.log,
      appUsageEntries: data.apps,
    );
    try {
      await write.timeout(cloudAckTimeout);
      _setCloudStatus(captureId, CloudSyncState.synced);
    } on TimeoutException {
      // Firestore keeps the batch in its offline queue and retries it; report
      // the honest state now and flip to synced if the server acknowledges it.
      _setCloudStatus(
        captureId,
        CloudSyncState.pendingOffline,
        'No response from Firestore within ${cloudAckTimeout.inSeconds}s. '
        'Data is kept on this device and will upload when online.',
      );
      unawaited(
        write.then(
          (_) => _setCloudStatus(captureId, CloudSyncState.synced),
          onError: (Object error) =>
              _setCloudStatus(captureId, _classify(error), '$error'),
        ),
      );
    } catch (error) {
      _setCloudStatus(captureId, _classify(error), '$error');
    }
  }

  void _setCloudStatus(
    String? captureId,
    CloudSyncState state, [
    String? message,
  ]) {
    // Ignore late results for an older capture.
    if (captureId != _latestCaptureId) {
      return;
    }
    cloudStatus.value = CloudSyncStatus(state, message: message, at: _clock());
  }

  static CloudSyncState _classify(Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return CloudSyncState.permissionDenied;
        case 'unauthenticated':
          return CloudSyncState.unauthenticated;
        case 'unavailable':
        case 'deadline-exceeded':
          return CloudSyncState.pendingOffline;
      }
    }
    return CloudSyncState.failed;
  }

  Future<Map<String, AppCategory>> _loadOverrides(String uid) async {
    final Map<String, AppCategory>? cached = _overrides;
    if (cached != null) {
      return cached;
    }
    try {
      final Map<String, AppCategory> loaded = await _repository
          .getCategoryOverrides(uid: uid)
          .timeout(readTimeout);
      _overrides = loaded;
      return loaded;
    } catch (error) {
      // Offline on first launch: categorise with defaults now, retry next sync.
      debugPrint('Category overrides unavailable: $error');
      return const <String, AppCategory>{};
    }
  }

  /// Changes an app's category for every day and re-publishes today's data.
  Future<void> setCategoryOverride(
    String packageName,
    AppCategory category,
  ) async {
    final String? uid = _currentUserId();
    if (uid == null) {
      return;
    }
    final Map<String, AppCategory> overrides = <String, AppCategory>{
      ...await _loadOverrides(uid),
    };
    if (category == AppCategory.uncategorized) {
      overrides.remove(packageName);
    } else {
      overrides[packageName] = category;
    }
    _overrides = overrides;

    final TodayActivity? current = today.value;
    if (current != null) {
      final List<AppUsageEntry> apps = current.apps.map((AppUsageEntry entry) {
        if (entry.packageName != packageName) {
          return entry;
        }
        return category == AppCategory.uncategorized
            ? _categoryService.categorizeEntry(entry)
            : entry.withCategory(category, userOverride: true);
      }).toList();
      final DailyActivityLog log = buildDailyLog(
        capture: _captureFromLog(current.log),
        apps: apps,
        date: current.log.date,
        captureId:
            current.log.captureId ?? '${_clock().millisecondsSinceEpoch}',
        syncedAt: current.log.lastSyncAt ?? _clock(),
        collectionStartedAt: current.log.collectionStartedAt,
      );
      today.value = TodayActivity(log: log, apps: apps);
      unawaited(_upload(uid, today.value!));
    }
    try {
      await _repository
          .setCategoryOverride(
            uid: uid,
            packageName: packageName,
            category: category,
          )
          .timeout(cloudAckTimeout);
    } on TimeoutException {
      // Queued in Firestore's offline cache; it uploads when back online.
    }
  }

  ActivityCaptureSnapshot _captureFromLog(DailyActivityLog log) {
    return ActivityCaptureSnapshot(
      start: log.date,
      end: ActivityDateUtils.nextDayStart(log.date),
      screenTimeMinutes: log.screenTimeMinutes,
      appUsageMinutes: log.appUsageMinutes,
      interactiveScreenTimeSeconds: log.interactiveScreenTimeSeconds,
      screenOnCount: log.screenOnCount,
      screenOffCount: log.screenOffCount,
      phoneUnlockCount: log.phoneUnlockCount,
      walkingMinutes: log.walkingMinutes,
      runningMinutes: log.runningMinutes,
      stillMinutes: log.stillMinutes,
      vehicleMinutes: log.vehicleMinutes,
      unknownActivityMinutes: log.unknownActivityMinutes,
      movementStatus: log.movementStatus,
      usagePermissionGranted: log.usagePermissionGranted ?? true,
      activityPermissionGranted: log.activityPermissionGranted ?? false,
      notificationPermissionGranted: log.notificationPermissionGranted ?? false,
      source: log.source,
      syncStatus: log.syncStatus,
      appUsageEntries: const <AppUsageEntry>[],
    );
  }

  /// Loads today's last uploaded snapshot (used when the device cannot measure,
  /// e.g. Usage Access revoked). Never overwrites a fresher local capture.
  Future<void> _loadCachedToday(String uid, DateTime now) async {
    try {
      final DailyActivityLog? log = await _repository
          .getDailyActivityLog(uid: uid, date: now)
          .timeout(readTimeout);
      if (log == null || today.value != null || _uid != uid) {
        return;
      }
      final List<AppUsageEntry> apps = await _repository
          .getDailyAppUsage(uid: uid, date: now, captureId: log.captureId)
          .timeout(readTimeout);
      if (today.value == null && _uid == uid) {
        today.value = TodayActivity(log: log, apps: apps);
      }
    } catch (error) {
      debugPrint('Cached activity unavailable: $error');
    }
  }

  ActivitySyncResult _publish(
    ActivitySyncState state,
    String message, {
    TodayActivity? today,
  }) {
    final ActivitySyncResult result = ActivitySyncResult(
      state: state,
      message: message,
      permissionSnapshot: permissions.value,
      syncedAt: _clock(),
      today: today,
    );
    latestResult.value = result;
    syncState.value = state;
    return result;
  }
}
