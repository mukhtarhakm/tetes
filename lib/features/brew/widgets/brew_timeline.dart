import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../brew_plan.dart';

class BrewTimeline extends StatelessWidget {
  const BrewTimeline({required this.plan, super.key});

  final BrewPlan plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.s12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: SizedBox(
            height: AppSizes.chipHeight,
            child: Row(children: _segments(context)),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s8,
          children: [
            _Legend(color: AppColors.primary, label: 'Menuang'),
            _Legend(color: AppColors.divider, label: 'Jeda'),
          ],
        ),
      ],
    );
  }

  List<Widget> _segments(BuildContext context) {
    final segments = <Widget>[];
    for (final stage in plan.stages) {
      segments.add(
        Expanded(
          flex: stage.durationSeconds,
          child: Container(
            color: AppColors.primary,
            alignment: Alignment.center,
            child: Text(
              stage.name.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ),
      );
      if (stage.gapAfterSeconds > 0) {
        segments.add(
          Expanded(
            flex: stage.gapAfterSeconds,
            child: const ColoredBox(color: AppColors.divider),
          ),
        );
      }
    }
    return segments;
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: AppSpacing.s12,
          height: AppSpacing.s12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
