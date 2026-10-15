import 'package:cloud_firestore/cloud_firestore.dart';

import 'activity_date_utils.dart';
import 'activity_sync_state.dart';
import 'app_usage_entry.dart';

/// One local day of automatically collected device data.
///
/// Two separate screen metrics are stored and must never be conflated:
///  * [appUsageMinutes]: union of the foreground time of launchable apps
///    (launcher and background system components excluded). This is what
///    Digital Wellbeing headlines as "screen time".
///  * [screenTimeMinutes]: how long the display was on **and unlocked**,
///    including time on the home screen. Null when the device does not report
///    screen events.
class DailyActivityLog {
  const DailyActivityLog({
    required this.date,
    this.screenTimeMinutes,
    this.appUsageMinutes,
    this.interactiveScreenTimeSeconds,
    this.phoneUnlockCount,
    this.screenOnCount,
    this.screenOffCount,
    this.productiveAppMinutes,
    this.distractingAppMinutes,
    this.neutralAppMinutes,
    this.uncategorizedAppMinutes,
    this.walkingMinutes,
    this.runningMinutes,
    this.stillMinutes,
    this.vehicleMinutes,
    this.unknownActivityMinutes,
    this.movementStatus,
    this.captureId,
    this.appSummary,
    this.lastSyncAt,
    this.collectionStartedAt,
    this.usagePermissionGranted,
    this.activityPermissionGranted,
    this.notificationPermissionGranted,
    this.source = 'android_usage_events',
    this.syncStatus = ActivitySyncState.idle,
    this.updatedAt,
  });

  /// Local midnight of the day this log describes.
  final DateTime date;
  final int? screenTimeMinutes;
  final int? appUsageMinutes;
  final int? interactiveScreenTimeSeconds;
  final int? phoneUnlockCount;
  final int? screenOnCount;
  final int? screenOffCount;
  final int? productiveAppMinutes;
  final int? distractingAppMinutes;
  final int? neutralAppMinutes;
  final int? uncategorizedAppMinutes;
  final int? walkingMinutes;
  final int? runningMinutes;
  final int? stillMinutes;
  final int? vehicleMinutes;
  final int? unknownActivityMinutes;

  /// `available`, `noSamples`, `notRegistered` or `permissionDenied`.
  final String? movementStatus;

  /// Identifies the capture that produced this log. App usage documents carry
  /// the same id; documents from older captures are stale and ignored.
  final String? captureId;

  /// Compact per-app usage for this day (no icons), written with each
  /// capture so history analysis does not have to read the icon-heavy
  /// `appUsage` subcollection. Null for days captured by older builds.
  final List<AppUsageEntry>? appSummary;
  final DateTime? lastSyncAt;
  final DateTime? collectionStartedAt;
  final bool? usagePermissionGranted;
  final bool? activityPermissionGranted;
  final bool? notificationPermissionGranted;
  final String source;
  final ActivitySyncState syncStatus;
  final DateTime? updatedAt;

  String get documentId => ActivityDateUtils.documentIdFor(date);

  bool get hasMovementData => movementStatus == 'available';

  int? get activeMinutes {
    if (!hasMovementData) {
      return null;
    }
    return (walkingMinutes ?? 0) + (runningMinutes ?? 0);
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      // The true instant of local midnight (for ordering) plus the day key,
      // which is the authoritative identity of the record.
      'date': Timestamp.fromDate(ActivityDateUtils.dayStart(date)),
      'dateKey': ActivityDateUtils.dayKey(date),
      'screenTimeMinutes': screenTimeMinutes,
      'appUsageMinutes': appUsageMinutes,
      // Legacy field names kept in sync for older app builds reading the doc.
      'totalScreenTimeMinutes': screenTimeMinutes,
      'trackedApplicationMinutes': appUsageMinutes,
      'interactiveScreenTimeSeconds': interactiveScreenTimeSeconds,
      'phoneUnlockCount': phoneUnlockCount,
      'screenOnCount': screenOnCount,
      'screenOffCount': screenOffCount,
      'productiveAppMinutes': productiveAppMinutes,
      'distractingAppMinutes': distractingAppMinutes,
      'neutralAppMinutes': neutralAppMinutes,
      'uncategorizedAppMinutes': uncategorizedAppMinutes,
      'walkingMinutes': walkingMinutes,
      'runningMinutes': runningMinutes,
      'stillMinutes': stillMinutes,
      'vehicleMinutes': vehicleMinutes,
      'unknownActivityMinutes': unknownActivityMinutes,
      'movementStatus': movementStatus,
      'captureId': captureId,
      // A list (not a map) so a merge write replaces it completely.
      'appSummary': appSummary
          ?.map(
            (AppUsageEntry e) => <String, dynamic>{
              'p': e.packageName,
              'n': e.appName,
              'c': e.category.value,
              'u': e.categoryIsUserOverride,
              'ms': e.foregroundDuration.inMilliseconds,
            },
          )
          .toList(),
      'lastSyncAt': lastSyncAt == null ? null : Timestamp.fromDate(lastSyncAt!),
      'collectionStartedAt': collectionStartedAt == null
          ? null
          : Timestamp.fromDate(collectionStartedAt!),
      'usagePermissionGranted': usagePermissionGranted,
      'activityPermissionGranted': activityPermissionGranted,
      'notificationPermissionGranted': notificationPermissionGranted,
      'source': source,
      'syncStatus': syncStatus.name,
    };
  }

  /// [documentId] is preferred over the stored `date` field because older
  /// builds wrote `date` under two different timezone conventions.
  factory DailyActivityLog.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    final DateTime date =
        ActivityDateUtils.parseKey(documentId) ??
        ActivityDateUtils.parseKey(map['dateKey']?.toString()) ??
        ActivityDateUtils.dayStart(_asDateTime(map['date']) ?? DateTime.now());
    return DailyActivityLog(
      date: date,
      // Older builds only wrote `totalScreenTimeMinutes`, which then held the
      // screen-interactive figure (including the lock screen); new builds write
      // `screenTimeMinutes`. App usage previously lived in
      // `trackedApplicationMinutes`.
      screenTimeMinutes: _asInt(
        map['screenTimeMinutes'] ?? map['totalScreenTimeMinutes'],
      ),
      appUsageMinutes: _asInt(
        map['appUsageMinutes'] ?? map['trackedApplicationMinutes'],
      ),
      interactiveScreenTimeSeconds: _asInt(map['interactiveScreenTimeSeconds']),
      phoneUnlockCount: _asInt(map['phoneUnlockCount']),
      screenOnCount: _asInt(map['screenOnCount']),
      screenOffCount: _asInt(map['screenOffCount']),
      productiveAppMinutes: _asInt(map['productiveAppMinutes']),
      distractingAppMinutes: _asInt(map['distractingAppMinutes']),
      neutralAppMinutes: _asInt(map['neutralAppMinutes']),
      uncategorizedAppMinutes: _asInt(map['uncategorizedAppMinutes']),
      walkingMinutes: _asInt(map['walkingMinutes']),
      runningMinutes: _asInt(map['runningMinutes']),
      stillMinutes: _asInt(map['stillMinutes']),
      vehicleMinutes: _asInt(map['vehicleMinutes']),
      unknownActivityMinutes: _asInt(map['unknownActivityMinutes']),
      movementStatus: map['movementStatus']?.toString(),
      captureId: map['captureId']?.toString(),
      appSummary: _parseAppSummary(map['appSummary']),
      lastSyncAt: _asDateTime(map['lastSyncAt']),
      collectionStartedAt: _asDateTime(map['collectionStartedAt']),
      usagePermissionGranted: map['usagePermissionGranted'] as bool?,
      activityPermissionGranted: map['activityPermissionGranted'] as bool?,
      notificationPermissionGranted:
          map['notificationPermissionGranted'] as bool?,
      source: map['source']?.toString() ?? 'android_usage_events',
      syncStatus: _syncStateFromValue(map['syncStatus']),
      updatedAt: _asDateTime(map['updatedAt']),
    );
  }

  static List<AppUsageEntry>? _parseAppSummary(dynamic raw) {
    if (raw is! List) return null;
    final List<AppUsageEntry> entries = <AppUsageEntry>[];
    for (final dynamic item in raw) {
      if (item is! Map) continue;
      final String? pkg = item['p']?.toString();
      final int? millis = _asInt(item['ms']);
      if (pkg == null || pkg.isEmpty || millis == null) continue;
      entries.add(
        AppUsageEntry(
          packageName: pkg,
          appName: item['n']?.toString() ?? pkg,
          usageMinutes: (millis / 60000).round(),
          foregroundDuration: Duration(milliseconds: millis),
          lastUsedAt: null,
          category: AppCategoryX.fromValue(item['c']?.toString()),
          categoryIsUserOverride: item['u'] == true,
          isSystemApp: false,
        ),
      );
    }
    return entries;
  }

  static int? _asInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.round();
    }
    return int.tryParse(value.toString());
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.tryParse(value.toString());
  }

  static ActivitySyncState _syncStateFromValue(dynamic value) {
    final String candidate = value?.toString() ?? ActivitySyncState.idle.name;
    return ActivitySyncState.values.firstWhere(
      (state) => state.name == candidate,
      orElse: () => ActivitySyncState.idle,
    );
  }
}
