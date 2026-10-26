import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

abstract final class ScoreChartTokens {
  static const double lineWidth = 2.5;
  static const double dotRadius = 4.0;
  static const double dotRadiusSelected = 6.0;
  static const double minY = 1.0;
  static const double maxY = 5.0;
  static const double gridIntervalY = 1.0;
  static const double gridIntervalX = 1.0;
  static const double gradientOpacityStart = 0.25;
  static const double gradientOpacityEnd = 0.0;
  static const double defaultHeight = 180.0;
  static const List<int> gridDashArray = [4, 4];
}

class ScoreChart extends StatelessWidget {
  const ScoreChart({
    required this.scores,
    this.height = ScoreChartTokens.defaultHeight,
    super.key,
  });

  final List<int> scores;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (scores.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Belum cukup data untuk grafik',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
        ),
      );
    }

    final spots = <FlSpot>[
      for (var i = 0; i < scores.length; i++)
        FlSpot((i + 1).toDouble(), scores[i].toDouble()),
    ];

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 1.0,
          maxX: scores.length.toDouble(),
          minY: ScoreChartTokens.minY,
          maxY: ScoreChartTokens.maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: ScoreChartTokens.gridIntervalY,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.divider,
              strokeWidth: 1.0,
              dashArray: ScoreChartTokens.gridDashArray,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: ScoreChartTokens.gridIntervalX,
                getTitlesWidget: (val, meta) {
                  final intVal = val.toInt();
                  if (val != intVal.toDouble() ||
                      intVal < 1 ||
                      intVal > scores.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s4),
                    child: Text(
                      '#$intVal',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: ScoreChartTokens.gridIntervalY,
                reservedSize: 28,
                getTitlesWidget: (val, meta) {
                  final intVal = val.toInt();
                  if (val != intVal.toDouble() || intVal < 1 || intVal > 5) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    '$intVal',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.ink,
              tooltipBorderRadius: BorderRadius.circular(AppRadius.navigation),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    'Seduhan #${spot.x.toInt()}\nSkor: ★ ${spot.y.toInt()}/5',
                    Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: AppColors.onDark,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: ScoreChartTokens.lineWidth,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: ScoreChartTokens.dotRadius,
                    color: AppColors.primary,
                    strokeWidth: 2,
                    strokeColor: AppColors.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(
                      alpha: ScoreChartTokens.gradientOpacityStart,
                    ),
                    AppColors.primary.withValues(
                      alpha: ScoreChartTokens.gradientOpacityEnd,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
