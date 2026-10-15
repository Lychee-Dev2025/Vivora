import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/activity_sync_snapshot.dart';
import '../models/activity_sync_state.dart';
import '../models/app_usage_entry.dart';

class UsagePackageDiagnostic {
  const UsagePackageDiagnostic({
    required this.packageName,
    required this.label,
    required this.eventCount,
    required this.eventDurationMs,
    required this.aggregateForegroundMs,
    required this.source,
    required this.selectionReason,
    required this.selectedDurationMs,
    this.excludedReason,
    this.aggregateFirstMs,
    this.aggregateLastMs,
    this.isSystemApp = false,
    this.isLauncher = false,
    this.lastUsedAt,
  });

  final String packageName;
  final String label;
  final int eventCount;
  final int eventDurationMs;
  final int? aggregateForegroundMs;
  final int? aggregateFirstMs;
  final int? aggregateLastMs;
  final String source;
  final String selectionReason;
  final int? selectedDurationMs;
  final String? excludedReason;
  final bool isSystemApp;
  final bool isLauncher;
  final int? lastUsedAt;
}

class UsageDiagnostics {
  const UsageDiagnostics({
    this.usageAccessGranted = false,
    this.screenInteractiveSeconds,
    this.trackedApplicationSeconds,
    this.foregroundApplicationSeconds,
    this.unlockCount,
    this.screenOnCount,
    this.screenOffCount,
    this.rawEventCount,
    this.excludedSystemCount,
    this.excludedOtherCount,
    this.packages = const <UsagePackageDiagnostic>[],
  });

  final bool usageAccessGranted;
  final int? screenInteractiveSeconds;
  final int? trackedApplicationSeconds;
  final int? foregroundApplicationSeconds;
  final int? unlockCount;
  final int? screenOnCount;
  final int? screenOffCount;
  final int? rawEventCount;
  final int? excludedSystemCount;
  final int? excludedOtherCount;
  final List<UsagePackageDiagnostic> packages;
}

/// Device-side activity source. Implemented by [AndroidActivityBridge]; tests
/// substitute a fake.
abstract class ActivityDataSource {
  Future<ActivityPermissionSnapshot> getPermissionSnapshot();
  Future<ActivitySyncMetadata> getSyncMetadata();
  Future<void> saveSyncMetadata(ActivitySyncMetadata metadata);
  Future<void> openUsageAccessSettings();
  Future<bool> requestActivityPermission();
  Future<bool> scheduleBackgroundSync();
  Future<ActivityCaptureSnapshot> captureActivityRange({
    required DateTime start,
    required DateTime end,
  });
}

class AndroidActivityBridge implements ActivityDataSource {
  AndroidActivityBridge._();

  static const MethodChannel _channel = MethodChannel(
    'vivora/activity_monitoring',
  );

  static final AndroidActivityBridge instance = AndroidActivityBridge._();

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<ActivityPermissionSnapshot> getPermissionSnapshot() async {
    if (!_isAndroid) {
      return const ActivityPermissionSnapshot(
        usageAccessGranted: false,
        activityPermissionGranted: false,
        notificationPermissionGranted: false,
        backgroundSyncEnabled: false,
      );
    }

    final Map<Object?, Object?> raw =
        await _channel.invokeMapMethod<Object?, Object?>(
          'getPermissionSnapshot',
        ) ??
        <Object?, Object?>{};
    return ActivityPermissionSnapshot.fromMap(
      raw.map((Object? key, Object? value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  Future<ActivitySyncMetadata> getSyncMetadata() async {
    if (!_isAndroid) {
      return const ActivitySyncMetadata();
    }

    final Map<Object?, Object?> raw =
        await _channel.invokeMapMethod<Object?, Object?>('getSyncMetadata') ??
        <Object?, Object?>{};
    return ActivitySyncMetadata.fromMap(
      raw.map((Object? key, Object? value) => MapEntry(key.toString(), value)),
    );
  }

  @override
  Future<void> saveSyncMetadata(ActivitySyncMetadata metadata) async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('saveSyncMetadata', metadata.toMap());
  }

  @override
  Future<void> openUsageAccessSettings() async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('openUsageAccessSettings');
  }

  @override
  Future<bool> requestActivityPermission() async {
    if (!_isAndroid) {
      return false;
    }
    final bool? granted = await _channel.invokeMethod<bool>(
      'requestActivityPermission',
    );
    return granted ?? false;
  }

  @override
  Future<bool> scheduleBackgroundSync() async {
    if (!_isAndroid) {
      return false;
    }
    final bool? scheduled = await _channel.invokeMethod<bool>(
      'scheduleBackgroundSync',
    );
    return scheduled ?? false;
  }

  Future<void> removeBackgroundSync() async {
    if (!_isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('removeBackgroundSync');
  }

  @override
  Future<ActivityCaptureSnapshot> captureActivityRange({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!_isAndroid) {
      return ActivityCaptureSnapshot(
        start: start,
        end: end,
        usagePermissionGranted: false,
        activityPermissionGranted: false,
        notificationPermissionGranted: false,
        source: 'unsupported_platform',
        syncStatus: ActivitySyncState.failed,
        appUsageEntries: const <AppUsageEntry>[],
      );
    }

    final Map<Object?, Object?> raw =
        await _channel.invokeMapMethod<Object?, Object?>(
          'captureActivityRange',
          <String, dynamic>{
            'startMillis': start.millisecondsSinceEpoch,
            'endMillis': end.millisecondsSinceEpoch,
          },
        ) ??
        <Object?, Object?>{};
    return parseCapture(
      raw.map((Object? key, Object? value) => MapEntry(key.toString(), value)),
      start: start,
      end: end,
    );
  }

  /// Converts the native capture map. Public for unit tests.
  static ActivityCaptureSnapshot parseCapture(
    Map<String, dynamic> map, {
    required DateTime start,
    required DateTime end,
  }) {
    final List<dynamic> entries =
        (map['appUsageEntries'] as List<dynamic>?) ?? <dynamic>[];

    return ActivityCaptureSnapshot(
      start: start,
      end: end,
      screenTimeMinutes: _asInt(map['totalScreenTimeMinutes']),
      appUsageMinutes: _asInt(map['trackedApplicationMinutes']),
      interactiveScreenTimeSeconds: _asInt(map['interactiveScreenTimeSeconds']),
      screenOnCount: _asInt(map['screenOnCount']),
      screenOffCount: _asInt(map['screenOffCount']),
      phoneUnlockCount: _asInt(map['phoneUnlockCount']),
      walkingMinutes: _asInt(map['walkingMinutes']),
      runningMinutes: _asInt(map['runningMinutes']),
      stillMinutes: _asInt(map['stillMinutes']),
      vehicleMinutes: _asInt(map['vehicleMinutes']),
      unknownActivityMinutes: _asInt(map['unknownActivityMinutes']),
      movementStatus: map['movementStatus']?.toString(),
      usagePermissionGranted: map['usagePermissionGranted'] == true,
      activityPermissionGranted: map['activityPermissionGranted'] == true,
      notificationPermissionGranted:
          map['notificationPermissionGranted'] == true,
      source: map['source']?.toString() ?? 'android_usage_events',
      syncStatus: ActivitySyncState.values.firstWhere(
        (state) => state.name == map['syncStatus']?.toString(),
        orElse: () => ActivitySyncState.failed,
      ),
      appUsageEntries: entries.whereType<Map>().map((dynamic rawEntry) {
        return AppUsageEntry.fromMap(
          Map<String, dynamic>.from(rawEntry as Map),
        );
      }).toList(),
      rawEventCount: _asInt(map['rawEventCount']),
      excludedSystemCount: _asInt(map['excludedSystemCount']),
    );
  }

  Future<UsageDiagnostics?> getUsageDiagnostics({
    required DateTime start,
    required DateTime end,
  }) async {
    if (!_isAndroid) {
      return null;
    }
    try {
      final Map<Object?, Object?> raw =
          await _channel.invokeMapMethod<Object?, Object?>(
            'getUsageDiagnostics',
            <String, dynamic>{
              'startMillis': start.millisecondsSinceEpoch,
              'endMillis': end.millisecondsSinceEpoch,
            },
          ) ??
          <Object?, Object?>{};
      final Map<String, dynamic> map = raw.map(
        (Object? key, Object? value) => MapEntry(key.toString(), value),
      );
      final List<dynamic> packages =
          (map['packages'] as List<dynamic>?) ?? <dynamic>[];

      return UsageDiagnostics(
        usageAccessGranted: map['usageAccessGranted'] == true,
        screenInteractiveSeconds: _asInt(map['screenInteractiveSeconds']),
        trackedApplicationSeconds: _asInt(map['trackedApplicationSeconds']),
        foregroundApplicationSeconds: _asInt(
          map['foregroundApplicationSeconds'],
        ),
        unlockCount: _asInt(map['unlockCount']),
        screenOnCount: _asInt(map['screenOnCount']),
        screenOffCount: _asInt(map['screenOffCount']),
        rawEventCount: _asInt(map['rawEventCount']),
        excludedSystemCount: _asInt(map['excludedSystemCount']),
        excludedOtherCount: _asInt(map['excludedOtherCount']),
        packages: packages.whereType<Map>().map((dynamic rawPackage) {
          final Map<String, dynamic> entry = Map<String, dynamic>.from(
            rawPackage as Map,
          );
          return UsagePackageDiagnostic(
            packageName: entry['packageName']?.toString() ?? '',
            label: entry['label']?.toString() ?? '',
            eventCount: _asInt(entry['eventCount']) ?? 0,
            eventDurationMs: _asInt(entry['eventDurationMs']) ?? 0,
            aggregateForegroundMs: _asInt(entry['aggregateForegroundMs']),
            aggregateFirstMs: _asInt(entry['aggregateFirstMs']),
            aggregateLastMs: _asInt(entry['aggregateLastMs']),
            source: entry['source']?.toString() ?? '',
            selectionReason: entry['selectionReason']?.toString() ?? '',
            selectedDurationMs: _asInt(entry['selectedDurationMs']),
            excludedReason: entry['excludedReason']?.toString(),
            isSystemApp: entry['isSystemApp'] == true,
            isLauncher: entry['isLauncher'] == true,
            lastUsedAt: _asInt(entry['lastUsedAt']),
          );
        }).toList(),
      );
    } catch (error) {
      debugPrint('Usage diagnostics unavailable: $error');
      return null;
    }
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
}
