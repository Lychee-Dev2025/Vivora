import 'models/analytics_models.dart';

class DummyAnalyticsProvider {
  static const AnalyticsStats currentStats = AnalyticsStats(
    productivityScore: '82%',
    screenTime: '4h 20m',
    focusHours: '3h 10m',
    sleepHours: '7h 25m',
    consistency: '76%',
  );

  static const List<ChartDataPoint> weeklyFocusData = [
    ChartDataPoint('Mon', 4.5),
    ChartDataPoint('Tue', 3.2),
    ChartDataPoint('Wed', 5.8),
    ChartDataPoint('Thu', 2.9),
    ChartDataPoint('Fri', 4.1),
    ChartDataPoint('Sat', 6.2),
    ChartDataPoint('Sun', 3.8),
  ];

  static const List<ChartDataPoint> focusVsDistractionData = [
    ChartDataPoint('Focus', 75),
    ChartDataPoint('Distraction', 25),
  ];

  static const List<ChartDataPoint> sleepTrendData = [
    ChartDataPoint('Mon', 7.5),
    ChartDataPoint('Tue', 6.8),
    ChartDataPoint('Wed', 8.2),
    ChartDataPoint('Thu', 7.1),
    ChartDataPoint('Fri', 6.5),
    ChartDataPoint('Sat', 9.2),
    ChartDataPoint('Sun', 8.5),
  ];

  static const List<AppUsageData> topApps = [
    AppUsageData(appName: 'VS Code', timeSpent: '2h 15m', percentage: 0.6),
    AppUsageData(appName: 'Chrome', timeSpent: '1h 10m', percentage: 0.3),
    AppUsageData(appName: 'Spotify', timeSpent: '45m', percentage: 0.1),
  ];

  static final List<ReportData> reports = [
    ReportData(
      id: 'd1',
      title: 'Daily Report',
      type: 'daily',
      summary: 'Focus sessions improved and distractions dropped by 12%.',
      stats: {
        'Screen Time': '4h 20m',
        'Focus Time': '3h 10m',
        'Sleep': '7h 25m',
        'Efficiency': '88%',
      },
      topApps: topApps,
      performanceSummary:
          'You had a very productive day today! Your deep focus sessions were 15% longer than your average. Keep it up!',
      trendData: weeklyFocusData,
    ),
    ReportData(
      id: 'w1',
      title: 'Weekly Report',
      type: 'weekly',
      summary: 'Consistency stayed high with strong evening study sessions.',
      stats: {
        'Avg Productivity': '78%',
        'Avg Sleep': '7h 10m',
        'Best Day': 'Saturday',
        'Focus Goal': 'Reached',
      },
      topApps: [
        AppUsageData(
          appName: 'VS Code',
          timeSpent: '18h 45m',
          percentage: 0.55,
        ),
        AppUsageData(appName: 'Chrome', timeSpent: '12h 30m', percentage: 0.35),
        AppUsageData(appName: 'Zoom', timeSpent: '4h 15m', percentage: 0.1),
      ],
      performanceSummary:
          'This week you showed great consistency in your morning routine. Your focus peaked on Wednesday and Saturday.',
      trendData: weeklyFocusData,
    ),
    ReportData(
      id: 'm1',
      title: 'Monthly Report',
      type: 'monthly',
      summary: 'Best month so far with stronger sleep and deeper focus.',
      stats: {
        'Overall Trend': '+12%',
        'Total Focus': '124h',
        'Sleep Quality': 'Excellent',
        'Best Week': 'Week 3',
      },
      topApps: [
        AppUsageData(appName: 'VS Code', timeSpent: '72h', percentage: 0.6),
        AppUsageData(appName: 'Chrome', timeSpent: '34h', percentage: 0.3),
        AppUsageData(appName: 'Others', timeSpent: '12h', percentage: 0.1),
      ],
      performanceSummary:
          'A stellar month! You successfully completed 95% of your planned focus sessions. Your sleep pattern is stabilizing.',
      trendData: weeklyFocusData,
    ),
  ];
}
