import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/display_format.dart';
import '../brew_plan.dart';
import 'brew_stage_colors.dart';

class BrewWaterChart extends StatelessWidget {
  const BrewWaterChart({
    required this.plan,
    this.chartHeight = AppSizes.statePreviewHeight,
    super.key,
  });

  final BrewPlan plan;
  final double chartHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Air kumulatif terhadap waktu',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          '${formatNumber(plan.totalWaterG)} g dalam ${plan.totalTimeSeconds} detik',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: AppSpacing.s16),
        SizedBox(
          height: chartHeight,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: plan.totalTimeSeconds.toDouble(),
              minY: 0,
              maxY: plan.totalWaterG,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.divider,
                  strokeWidth: AppSizes.progressStroke,
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
                  axisNameWidget: Text(
                    'Waktu (detik)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  sideTitles: const SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: Text(
                    'Air (g)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  sideTitles: const SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: _lineBars(),
            ),
          ),
        ),
      ],
    );
  }

  List<LineChartBarData> _lineBars() {
    final lines = <LineChartBarData>[];
    var cumulativeWater = 0.0;
    for (final stage in plan.stages) {
      final startWater = cumulativeWater;
      cumulativeWater += stage.targetPourG;
      lines.add(
        LineChartBarData(
          spots: [
            FlSpot(stage.startSeconds.toDouble(), startWater),
            FlSpot(stage.endSeconds.toDouble(), cumulativeWater),
          ],
          isCurved: false,
          color: BrewStageColors.forPosition(stage.position),
          barWidth: AppSizes.progressStroke,
          dotData: const FlDotData(show: false),
        ),
      );
    }
    return lines;
  }
}
