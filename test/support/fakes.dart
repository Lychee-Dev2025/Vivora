import 'dart:async';

import 'package:vivora/features/activity_monitoring/data/models/activity_sync_snapshot.dart';
import 'package:vivora/features/activity_monitoring/data/models/activity_sync_state.dart';
import 'package:vivora/features/activity_monitoring/data/models/app_usage_entry.dart';
import 'package:vivora/features/activity_monitoring/data/models/daily_activity_log.dart';
import 'package:vivora/features/activity_monitoring/data/repositories/activity_repository.dart';
import 'package:vivora/features/activity_monitoring/data/services/android_activity_bridge.dart';

AppUsageEntry app(
  String packageName,
  String name,
  Duration duration, {
  AppCategory category = AppCategory.uncategorized,
  String? captureId,
}) {
  return AppUsageEntry(
    packageName: packageName,
    appName: name,
    usageMinutes: (duration.inSeconds / 60).round(),
    foregroundDuration: duration,
    lastUsedAt: null,
    category: category,
    isSystemApp: false,
    captureId: captureId,
  );
}

/// Synthetic device data; never touches a real phone.
class FakeDataSource implements ActivityDataSource {
  FakeDataSource({
    this.permissions = const ActivityPermissionSnapshot(
      usageAccessGranted: true,
      activityPermissionGranted: true,
      notificationPermissionGranted: true,
      backgroundSyncEnabled: true,
    ),
    List<AppUsageEntry>? apps,
    this.screenTimeMinutes = 50,
    this.appUsageMinutes = 45,
  }) : apps =
           apps ??
           <AppUsageEntry>[
             app('com.example.vivora', 'Vivora', const Duration(minutes: 22)),
             app(
               'com.google.android.youtube',
               'YouTube',
               const Duration(minutes: 11, seconds: 20),
             ),
             app('com.whatsapp', 'WhatsApp', const Duration(minutes: 6)),
           ];

  ActivityPermissionSnapshot permissions;
  List<AppUsageEntry> apps;
  int? screenTimeMinutes;
  int? appUsageMinutes;
  int captureCalls = 0;
  ActivitySyncMetadata metadata = const ActivitySyncMetadata();

  @override
  Future<ActivityCaptureSnapshot> captureActivityRange({
    required DateTime start,
    required DateTime end,
  }) async {
    captureCalls++;
    return ActivityCaptureSnapshot(
      start: start,
      end: end,
      screenTimeMinutes: screenTimeMinutes,
      appUsageMinutes: appUsageMinutes,
      phoneUnlockCount: 12,
      movementStatus: 'noSamples',
      usagePermissionGranted: permissions.usageAccessGranted,
      activityPermissionGranted: permissions.activityPermissionGranted,
      notificationPermissionGranted: true,
      syncStatus: ActivitySyncState.success,
      appUsageEntries: List<AppUsageEntry>.of(apps),
    );
  }

  @override
  Future<ActivityPermissionSnapshot> getPermissionSnapshot() async =>
      permissions;

  @override
  Future<ActivitySyncMetadata> getSyncMetadata() async => metadata;

  @override
  Future<void> saveSyncMetadata(ActivitySyncMetadata value) async =>
      metadata = value;

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<bool> requestActivityPermission() async => true;

  @override
  Future<bool> scheduleBackgroundSync() async => true;
}

/// In-memory stand-in for Firestore. [writeGate] lets a test hold a write
/// "in flight" to simulate being offline.
class FakeActivityRepository implements ActivityRepository {
  final Map<String, DailyActivityLog> logs = <String, DailyActivityLog>{};
  final Map<String, Map<String, AppUsageEntry>> appUsage =
      <String, Map<String, AppUsageEntry>>{};
  Map<String, AppCategory> overrides = <String, AppCategory>{};
  Completer<void>? writeGate;
  Object? writeError;
  int writes = 0;

  @override
  Future<void> upsertDailyActivityLog({
    required String uid,
    required DailyActivityLog log,
    required List<AppUsageEntry> appUsageEntries,
  }) async {
    writes++;
    // Like Firestore, the local cache is updated immediately.
    logs['$uid/${log.documentId}'] = log;
    final Map<String, AppUsageEntry> day = appUsage.putIfAbsent(
      '$uid/${log.documentId}',
      () => <String, AppUsageEntry>{},
    );
    for (final AppUsageEntry entry in appUsageEntries) {
      day[entry.packageName] = entry.copyWith(captureId: log.captureId);
    }
    if (writeError != null) throw writeError!;
    if (writeGate != null) await writeGate!.future;
  }

  @override
  Future<DailyActivityLog?> getDailyActivityLog({
    required String uid,
    required DateTime date,
  }) async {
    for (final MapEntry<String, DailyActivityLog> e in logs.entries) {
      if (e.key.startsWith('$uid/')) return e.value;
    }
    return null;
  }

  @override
  Future<List<AppUsageEntry>> getDailyAppUsage({
    required String uid,
    required DateTime date,
    String? captureId,
  }) async {
    final List<AppUsageEntry> all = appUsage.entries
        .where((e) => e.key.startsWith('$uid/'))
        .expand((e) => e.value.values)
        .toList();
    return ActivityRepository.filterCurrentCapture(all, captureId);
  }

  @override
  Future<Map<String, AppCategory>> getCategoryOverrides({
    required String uid,
  }) async => Map<String, AppCategory>.of(overrides);

  @override
  Future<void> setCategoryOverride({
    required String uid,
    required String packageName,
    required AppCategory category,
  }) async {
    if (category == AppCategory.uncategorized) {
      overrides.remove(packageName);
    } else {
      overrides[packageName] = category;
    }
  }

  @override
  Future<List<DailyActivityLog>> getActivityLogsForLastDays({
    required String uid,
    required int days,
    DateTime? today,
  }) async => logs.values.toList();
}
