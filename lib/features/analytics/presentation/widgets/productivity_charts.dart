import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:vivora/core/theme/vivora_palette.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/analytics_models.dart';

/// Centered message used instead of an empty chart.
class ChartEmptyState extends StatelessWidget {
  const ChartEmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.textSecondary),
        ),
      ),
    );
  }
}

double _niceMax(Iterable<double> values, {double minimum = 1}) {
  final double peak = values.fold<double>(0, max);
  if (peak <= 0) return minimum;
  final double padded = peak * 1.15;
  return max(minimum, padded.ceilToDouble());
}

/// Line chart for a value per day. Missing days are not drawn (no invented
/// points); [ChartDataPoint.label] is shown under each point.
class WeeklyProductivityChart extends StatelessWidget {
  const WeeklyProductivityChart({
    super.key,
    required this.data,
    this.maxY,
    this.unit = '',
  });

  final List<ChartDataPoint> data;
  final double? maxY;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return ChartEmptyState(message: 'No data recorded yet.');
    }
    final double top = maxY ?? _niceMax(data.map((d) => d.value));
    final bool single = data.length == 1;
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: top / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: context.brand.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final int index = value.round();
                if ((value - index).abs() > 0.01 ||
                    index < 0 ||
                    index >= data.length) {
                  return SizedBox.shrink();
                }
                return Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    data[index].label,
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: top / 4,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => Text(
                '${value.round()}$unit',
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: single ? -0.5 : 0,
        maxX: single ? 0.5 : (data.length - 1).toDouble(),
        minY: 0,
        maxY: top,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    '${data[s.x.round()].label}: ${s.y.toStringAsFixed(s.y % 1 == 0 ? 0 : 1)}$unit',
                    TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: <FlSpot>[
              for (int i = 0; i < data.length; i++)
                FlSpot(i.toDouble(), data[i].value),
            ],
            isCurved: data.length > 2,
            preventCurveOverShooting: true,
            gradient: LinearGradient(
              colors: [context.brand, AppColors.secondaryCyan],
            ),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  context.brand.withValues(alpha: 0.2),
                  AppColors.secondaryCyan.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whole-number percentages for [values] that always add up to 100 (largest
/// remainder method), or all zeros when the total is zero. Never divides by 0.
List<int> sharePercentages(List<double> values) {
  final double total = values.fold<double>(0, (sum, v) => sum + max(0, v));
  if (total <= 0) {
    return List<int>.filled(values.length, 0);
  }
  final List<double> exact = values
      .map((v) => max(0, v) / total * 100)
      .toList();
  final List<int> result = exact.map((v) => v.floor()).toList();
  int missing = 100 - result.fold<int>(0, (sum, v) => sum + v);
  final List<int> order = List<int>.generate(values.length, (i) => i)
    ..sort((a, b) => (exact[b] - result[b]).compareTo(exact[a] - result[a]));
  for (final int i in order) {
    if (missing <= 0) break;
    result[i]++;
    missing--;
  }
  return result;
}

/// Doughnut of two or more shares. [ChartDataPoint.value] is an absolute
/// amount in minutes; percentages are computed here.
///
/// Layout: the ring is sized from the available width (never wider than its
/// card), the dominant share is written in the centre hole, and the legend is
/// a separate block below, so nothing can overlap or be clipped. On wide cards
/// (≥ 420 px) the legend moves beside the ring.
class FocusVsDistractionChart extends StatelessWidget {
  const FocusVsDistractionChart({
    super.key,
    required this.data,
    this.colors = const <Color>[AppColors.primaryBlue, AppColors.softPurple],
    this.emptyMessage = 'No productive or distracting app time recorded yet.',
  });

  final List<ChartDataPoint> data;
  final List<Color> colors;
  final String emptyMessage;

  static const double maxDiameter = 180;
  static const double wideLayoutWidth = 420;

  @override
  Widget build(BuildContext context) {
    final List<int> percents = sharePercentages(
      data.map((d) => d.value).toList(),
    );
    final double total = data.fold<double>(
      0,
      (sum, d) => sum + max(0, d.value),
    );
    if (total <= 0) {
      return SizedBox(
        height: 120,
        child: ChartEmptyState(message: emptyMessage),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide = constraints.maxWidth >= wideLayoutWidth;
        final double available = wide
            ? constraints.maxWidth * 0.45
            : constraints.maxWidth;
        double diameter = min(maxDiameter, available);
        if (!wide && constraints.hasBoundedHeight) {
          // Leave room for the legend (two lines per row in the worst case)
          // when a caller gives the chart a fixed height.
          final double row = MediaQuery.textScalerOf(context).scale(14) * 1.4;
          final double legend = data.length * (row * 2 + 8) + 16;
          diameter = max(60, min(diameter, constraints.maxHeight - legend));
        }
        final Widget ring = _Ring(
          diameter: diameter,
          data: data,
          percents: percents,
          colors: colors,
        );
        final Widget legend = _Legend(
          data: data,
          percents: percents,
          colors: colors,
        );

        if (wide) {
          return Row(
            children: <Widget>[
              ring,
              const SizedBox(width: 24),
              Expanded(child: legend),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Center(child: ring),
            const SizedBox(height: 16),
            legend,
          ],
        );
      },
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.diameter,
    required this.data,
    required this.percents,
    required this.colors,
  });

  final double diameter;
  final List<ChartDataPoint> data;
  final List<int> percents;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final double thickness = diameter * 0.17;
    final List<int> visible = <int>[
      for (int i = 0; i < data.length; i++)
        if (data[i].value > 0) i,
    ];
    int dominant = 0;
    for (int i = 1; i < percents.length; i++) {
      if (percents[i] > percents[dominant]) dominant = i;
    }
    final double hole = diameter - 2 * thickness - 8;

    return SizedBox.square(
      dimension: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: visible.length > 1 ? 2 : 0,
              centerSpaceRadius: diameter / 2 - thickness,
              pieTouchData: PieTouchData(enabled: false),
              sections: <PieChartSectionData>[
                for (final int i in visible)
                  PieChartSectionData(
                    color: colors[i % colors.length],
                    value: data[i].value,
                    radius: thickness,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          // The centre text is scaled down to always fit inside the hole.
          SizedBox.square(
            dimension: hole * 0.72,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${percents[dominant]}%',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: colors[dominant % colors.length],
                    ),
                  ),
                  Text(
                    data[dominant].label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.data,
    required this.percents,
    required this.colors,
  });

  final List<ChartDataPoint> data;
  final List<int> percents;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < data.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: colors[i % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Label and value share a Wrap: on a narrow card or at a large
                // font size the value moves under the label instead of
                // overflowing the row.
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 2,
                    alignment: WrapAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        data[i].label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      Text(
                        '${_minutes(data[i].value)} · ${percents[i]}%',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _minutes(double value) {
    final int m = value.round();
    if (m < 60) return '${m}m';
    return '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';
  }
}

/// Bar chart for a value per day.
class SleepTrendChart extends StatelessWidget {
  const SleepTrendChart({super.key, required this.data, this.unit = 'h'});

  final List<ChartDataPoint> data;
  final String unit;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const ChartEmptyState(message: 'No data recorded yet.');
    }
    final double top = _niceMax(data.map((d) => d.value));
    return BarChart(
      BarChartData(
        maxY: top,
        minY: 0,
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < data.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: data[i].value,
                  gradient: const LinearGradient(
                    colors: [AppColors.secondaryCyan, AppColors.accentGreen],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    data[index].label,
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: top / 4,
              getTitlesWidget: (value, meta) => Text(
                '${value.round()}$unit',
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}
