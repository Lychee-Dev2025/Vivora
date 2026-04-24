class AnalyticsStats {
  final String productivityScore;
  final String screenTime;
  final String focusHours;
  final String sleepHours;
  final String consistency;

  const AnalyticsStats({
    required this.productivityScore,
    required this.screenTime,
    required this.focusHours,
    required this.sleepHours,
    required this.consistency,
  });
}

class ChartDataPoint {
  final String label;
  final double value;

  const ChartDataPoint(this.label, this.value);
}

class AppUsageData {
  final String appName;
  final String timeSpent;
  final double percentage;

  const AppUsageData({
    required this.appName,
    required this.timeSpent,
    required this.percentage,
  });
}

class ReportData {
  final String id;
  final String title;
  final String type; // 'daily', 'weekly', 'monthly'
  final String summary;
  final Map<String, String> stats;
  final List<AppUsageData> topApps;
  final String performanceSummary;
  final List<ChartDataPoint> trendData;

  const ReportData({
    required this.id,
    required this.title,
    required this.type,
    required this.summary,
    required this.stats,
    required this.topApps,
    required this.performanceSummary,
    required this.trendData,
  });
}
