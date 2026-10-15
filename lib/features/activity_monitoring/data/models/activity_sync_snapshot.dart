import 'activity_sync_state.dart';
import 'app_usage_entry.dart';
import 'daily_activity_log.dart';

class ActivityPermissionSnapshot {
  const ActivityPermissionSnapshot({
    required this.usageAccessGranted,
    required this.activityPermissionGranted,
    required this.notificationPermissionGranted,
    required this.backgroundSyncEnabled,
  });

  static const ActivityPermissionSnapshot unknown = ActivityPermissionSnapshot(
    usageAccessGranted: false,
    activityPermissionGranted: false,
    notificationPermissionGranted: false,
    backgroundSyncEnabled: false,
  );

  final bool usageAccessGranted;
  final bool activityPermissionGranted;
  final bool notificationPermissionGranted;

  /// True only after Play services confirmed the activity-recognition
  /// registration.
  final bool backgroundSyncEnabled;

  factory ActivityPermissionSnapshot.fromMap(Map<String, dynamic> map) {
    return ActivityPermissionSnapshot(
      usageAccessGranted: map['usageAccessGranted'] == true,
      activityPermissionGranted: map['activityPermissionGranted'] == true,
      notificationPermissionGranted:
          map['notificationPermissionGranted'] == true,
      backgroundSyncEnabled: map['backgroundSyncEnabled'] == true,
    );
  }
}

class ActivitySyncMetadata {
  const ActivitySyncMetadata({
    this.lastSuccessfulActivitySync,
    this.lastBackgroundSync,
    this.lastUsagePermissionState,
    this.lastActivityPermissionState,
    this.collectionStartedAt,
    this.lastSyncedUserId,
  });

  final DateTime? lastSuccessfulActivitySync;
  final DateTime? lastBackgroundSync;
  final bool? lastUsagePermissionState;
  final bool? lastActivityPermissionState;
  final DateTime? collectionStartedAt;
  final String? lastSyncedUserId;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'lastSuccessfulActivitySync':
          lastSuccessfulActivitySync?.millisecondsSinceEpoch,
      'lastBackgroundSync': lastBackgroundSync?.millisecondsSinceEpoch,
      'lastUsagePermissionState': lastUsagePermissionState,
      'lastActivityPermissionState': lastActivityPermissionState,
      'collectionStartedAt': collectionStartedAt?.millisecondsSinceEpoch,
      'lastSyncedUserId': lastSyncedUserId,
    };
  }

  factory ActivitySyncMetadata.fromMap(Map<String, dynamic> map) {
    return ActivitySyncMetadata(
      lastSuccessfulActivitySync: _asDateTime(
        map['lastSuccessfulActivitySync'],
      ),
      lastBackgroundSync: _asDateTime(map['lastBackgroundSync']),
      lastUsagePermissionState: map['lastUsagePermissionState'] as bool?,
      lastActivityPermissionState: map['lastActivityPermissionState'] as bool?,
      collectionStartedAt: _asDateTime(map['collectionStartedAt']),
      lastSyncedUserId: map['lastSyncedUserId']?.toString(),
    );
  }

  ActivitySyncMetadata copyWith({
    DateTime? lastSuccessfulActivitySync,
    bool? lastUsagePermissionState,
    bool? lastActivityPermissionState,
    DateTime? collectionStartedAt,
    String? lastSyncedUserId,
  }) {
    return ActivitySyncMetadata(
      lastSuccessfulActivitySync:
          lastSuccessfulActivitySync ?? this.lastSuccessfulActivitySync,
      lastBackgroundSync: lastBackgroundSync,
      lastUsagePermissionState:
          lastUsagePermissionState ?? this.lastUsagePermissionState,
      lastActivityPermissionState:
          lastActivityPermissionState ?? this.lastActivityPermissionState,
      collectionStartedAt: collectionStartedAt ?? this.collectionStartedAt,
      lastSyncedUserId: lastSyncedUserId ?? this.lastSyncedUserId,
    );
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null || value == 0) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.tryParse(value.toString());
  }
}

/// Raw result of one native capture of a local-day window.
class ActivityCaptureSnapshot {
  const ActivityCaptureSnapshot({
    required this.start,
    required this.end,
    required this.usagePermissionGranted,
    required this.activityPermissionGranted,
    required this.notificationPermissionGranted,
    required this.syncStatus,
    required this.appUsageEntries,
    this.screenTimeMinutes,
    this.appUsageMinutes,
    this.interactiveScreenTimeSeconds,
    this.screenOnCount,
    this.screenOffCount,
    this.phoneUnlockCount,
    this.walkingMinutes,
    this.runningMinutes,
    this.stillMinutes,
    this.vehicleMinutes,
    this.unknownActivityMinutes,
    this.movementStatus,
    this.source = 'android_usage_events',
    this.rawEventCount,
    this.excludedSystemCount,
  });

  final DateTime start;
  final DateTime end;

  /// Screen on and unlocked. Null = the device does not report it.
  final int? screenTimeMinutes;

  /// Union of launchable apps' foreground time (Digital-Wellbeing-style total).
  final int? appUsageMinutes;
  final int? interactiveScreenTimeSeconds;
  final int? screenOnCount;
  final int? screenOffCount;
  final int? phoneUnlockCount;
  final int? walkingMinutes;
  final int? runningMinutes;
  final int? stillMinutes;
  final int? vehicleMinutes;
  final int? unknownActivityMinutes;
  final String? movementStatus;
  final bool usagePermissionGranted;
  final bool activityPermissionGranted;
  final bool notificationPermissionGranted;
  final String source;
  final ActivitySyncState syncStatus;
  final List<AppUsageEntry> appUsageEntries;
  final int? rawEventCount;
  final int? excludedSystemCount;
}

/// Whether the latest local capture reached Firestore.
enum CloudSyncState {
  /// Nothing has been written yet in this session.
  idle,

  /// Write sent; the server has not acknowledged it yet.
  uploading,

  /// Server acknowledged the write.
  synced,

  /// No server acknowledgement in time (typically offline / DNS failure). The
  /// write stays queued in Firestore's offline cache and is retried
  /// automatically.
  pendingOffline,

  /// Rejected by security rules; retrying will not help.
  permissionDenied,

  /// The user is not signed in (or the token expired).
  unauthenticated,

  /// Any other failure (e.g. invalid data).
  failed,
}

class CloudSyncStatus {
  const CloudSyncStatus(this.state, {this.message, this.at});

  static const CloudSyncStatus idle = CloudSyncStatus(CloudSyncState.idle);

  final CloudSyncState state;
  final String? message;
  final DateTime? at;

  String get label {
    switch (state) {
      case CloudSyncState.idle:
        return 'Not uploaded yet';
      case CloudSyncState.uploading:
        return 'Uploading…';
      case CloudSyncState.synced:
        return 'Saved to cloud';
      case CloudSyncState.pendingOffline:
        return 'Saved on device, waiting for network';
      case CloudSyncState.permissionDenied:
        return 'Cloud rejected the write (permission)';
      case CloudSyncState.unauthenticated:
        return 'Sign in again to upload';
      case CloudSyncState.failed:
        return 'Cloud upload failed';
    }
  }
}

/// Everything the UI needs about today's automatically collected data.
class TodayActivity {
  const TodayActivity({required this.log, required this.apps});

  final DailyActivityLog log;

  /// Sorted by duration, longest first.
  final List<AppUsageEntry> apps;
}

class ActivitySyncResult {
  const ActivitySyncResult({
    required this.state,
    required this.message,
    required this.permissionSnapshot,
    required this.syncedAt,
    this.today,
    this.throttled = false,
  });

  final ActivitySyncState state;
  final String message;
  final ActivityPermissionSnapshot permissionSnapshot;
  final DateTime syncedAt;
  final TodayActivity? today;
  final bool throttled;
}
