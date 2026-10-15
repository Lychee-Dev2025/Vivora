import 'package:cloud_firestore/cloud_firestore.dart';

enum AppCategory { productive, distracting, neutral, uncategorized }

extension AppCategoryX on AppCategory {
  String get value => name;

  String get label => name[0].toUpperCase() + name.substring(1);

  static AppCategory fromValue(String? value) {
    switch (value) {
      case 'productive':
        return AppCategory.productive;
      case 'distracting':
        return AppCategory.distracting;
      case 'neutral':
        return AppCategory.neutral;
      default:
        return AppCategory.uncategorized;
    }
  }
}

class AppUsageEntry {
  const AppUsageEntry({
    required this.packageName,
    required this.appName,
    this.iconBase64,
    required this.usageMinutes,
    required this.foregroundDuration,
    required this.lastUsedAt,
    required this.category,
    required this.isSystemApp,
    this.isLauncher = false,
    this.categoryIsUserOverride = false,
    this.captureId,
  });

  final String packageName;
  final String appName;
  final String? iconBase64;

  /// Rounded to the nearest minute. Use [foregroundDuration] for arithmetic.
  final int usageMinutes;
  final Duration foregroundDuration;
  final DateTime? lastUsedAt;
  final AppCategory category;
  final bool isSystemApp;
  final bool isLauncher;
  final bool categoryIsUserOverride;
  final String? captureId;

  String get displayName => appName.isNotEmpty ? appName : packageName;

  /// "1h 05m", "12m" or "<1m" for real but short usage.
  String get durationLabel => formatUsageDuration(foregroundDuration);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'packageName': packageName,
      'appName': appName,
      'iconBase64': iconBase64,
      'usageMinutes': usageMinutes,
      'foregroundDurationMillis': foregroundDuration.inMilliseconds,
      'lastUsedAt': lastUsedAt == null ? null : Timestamp.fromDate(lastUsedAt!),
      'category': category.value,
      'categorySource': categoryIsUserOverride ? 'user' : 'automatic',
      'isSystemApp': isSystemApp,
      'isLauncher': isLauncher,
      'captureId': captureId,
    };
  }

  factory AppUsageEntry.fromMap(Map<String, dynamic> map) {
    final int millis =
        _asInt(map['foregroundDurationMillis'] ?? map['foregroundDuration']) ??
        ((_asInt(map['usageMinutes']) ?? 0) * 60000);
    return AppUsageEntry(
      packageName: map['packageName']?.toString() ?? '',
      appName: map['appName']?.toString() ?? '',
      usageMinutes: _asInt(map['usageMinutes']) ?? (millis / 60000).round(),
      foregroundDuration: Duration(milliseconds: millis),
      lastUsedAt: _asDateTime(map['lastUsedAt']),
      category: AppCategoryX.fromValue(map['category']?.toString()),
      categoryIsUserOverride: map['categorySource'] == 'user',
      isSystemApp: map['isSystemApp'] == true,
      isLauncher: map['isLauncher'] == true,
      iconBase64: map['iconBase64']?.toString(),
      captureId: map['captureId']?.toString(),
    );
  }

  AppUsageEntry copyWith({
    AppCategory? category,
    bool? categoryIsUserOverride,
    String? captureId,
  }) {
    return AppUsageEntry(
      packageName: packageName,
      appName: appName,
      iconBase64: iconBase64,
      usageMinutes: usageMinutes,
      foregroundDuration: foregroundDuration,
      lastUsedAt: lastUsedAt,
      category: category ?? this.category,
      isSystemApp: isSystemApp,
      isLauncher: isLauncher,
      categoryIsUserOverride:
          categoryIsUserOverride ?? this.categoryIsUserOverride,
      captureId: captureId ?? this.captureId,
    );
  }

  AppUsageEntry withCategory(
    AppCategory category, {
    bool userOverride = false,
  }) {
    return copyWith(category: category, categoryIsUserOverride: userOverride);
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
    if (value is DateTime) {
      return value;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

/// Formats a duration for usage lists: "1h 05m", "12m", "<1m", "0m".
String formatUsageDuration(Duration duration) {
  if (duration <= Duration.zero) {
    return '0m';
  }
  final int totalMinutes = (duration.inSeconds / 60).round();
  if (totalMinutes < 1) {
    return '<1m';
  }
  return formatMinutes(totalMinutes);
}

/// "1h 05m" / "45m".
String formatMinutes(int minutes) {
  if (minutes < 60) {
    return '${minutes}m';
  }
  final int hours = minutes ~/ 60;
  final int rest = minutes % 60;
  return '${hours}h ${rest.toString().padLeft(2, '0')}m';
}
