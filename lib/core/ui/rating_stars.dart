import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

class RatingStars extends StatelessWidget {
  const RatingStars({required this.score, this.compact = false, super.key});

  final int score;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = Theme.of(context).textTheme.bodyLarge?.fontSize;
    return Semantics(
      label: 'Skor $score dari 5',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < (compact ? 1 : 5); index++)
              Icon(
                Icons.star_rounded,
                size: iconSize,
                color: compact || index < score
                    ? AppColors.rating
                    : AppColors.divider,
              ),
            const SizedBox(width: AppSpacing.s4),
            Text(
              '$score/5',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
