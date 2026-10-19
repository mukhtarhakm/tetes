import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../brew_plan.dart';
import 'brew_stage_colors.dart';

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
            color: BrewStageColors.forPosition(stage.position),
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
    }
    return segments;
  }
}
