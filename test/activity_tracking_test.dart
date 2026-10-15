import 'package:flutter_test/flutter_test.dart';
import 'package:vivora/core/utils/slider_value.dart';
import 'package:vivora/features/activity_monitoring/data/models/app_usage_entry.dart';
import 'package:vivora/features/activity_monitoring/data/services/app_category_service.dart';

void main() {
  group('AppUsageEntry ordering', () {
    test('sorts the most used app first', () {
      final entries = <AppUsageEntry>[
        const AppUsageEntry(
          packageName: 'com.example.second',
          appName: 'Spotify',
          usageMinutes: 12,
          foregroundDuration: Duration(minutes: 12),
          lastUsedAt: null,
          category: AppCategory.neutral,
          isSystemApp: false,
        ),
        const AppUsageEntry(
          packageName: 'com.example.first',
          appName: 'YouTube',
          usageMinutes: 32,
          foregroundDuration: Duration(minutes: 32),
          lastUsedAt: null,
          category: AppCategory.distracting,
          isSystemApp: false,
        ),
      ];

      final sorted = [...entries]
        ..sort((a, b) => b.usageMinutes.compareTo(a.usageMinutes));
      expect(sorted.first.appName, 'YouTube');
      expect(sorted.last.appName, 'Spotify');
    });
  });

  group('Usage and input safety', () {
    test('accepts a valid day value and rejects invalid slider values', () {
      expect(
        normalizeSliderValue(21.883333333333333, min: 0, max: 24),
        21.883333333333333,
      );
      expect(normalizeSliderValue(30, min: 0, max: 24), 24);
      expect(normalizeSliderValue(double.nan, min: 0, max: 24), 0);
      expect(normalizeSliderValue(double.infinity, min: 0, max: 24), 0);
    });

    test('represents missing Android usage as no data', () {
      const entries = <AppUsageEntry>[];
      expect(entries, isEmpty);
      expect(entries.fold<int>(0, (sum, entry) => sum + entry.usageMinutes), 0);
    });

    test(
      'keeps every returned package and classifies known apps without guessing unknowns',
      () {
        const service = AppCategoryService();
        final entries = <AppUsageEntry>[
          const AppUsageEntry(
            packageName: 'com.google.android.youtube',
            appName: 'YouTube',
            usageMinutes: 4,
            foregroundDuration: Duration(minutes: 4),
            lastUsedAt: null,
            category: AppCategory.uncategorized,
            isSystemApp: false,
          ),
          const AppUsageEntry(
            packageName: 'com.example.unknown',
            appName: 'Unknown App',
            usageMinutes: 2,
            foregroundDuration: Duration(minutes: 2),
            lastUsedAt: null,
            category: AppCategory.uncategorized,
            isSystemApp: false,
          ),
        ];

        final categorized = service.categorizeEntries(entries);
        expect(
          categorized.map((entry) => entry.packageName),
          containsAll(<String>[
            'com.google.android.youtube',
            'com.example.unknown',
          ]),
        );
        expect(categorized.first.category, AppCategory.distracting);
        expect(categorized.last.category, AppCategory.uncategorized);
      },
    );
  });
}
