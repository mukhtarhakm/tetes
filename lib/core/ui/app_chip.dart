import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    this.selected = false,
    this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = selected
        ? AppColors.primary
        : isDark
        ? AppColors.chipDark
        : AppColors.background;
    final chip = AnimatedContainer(
      duration: AppDurations.feedback,
      constraints: BoxConstraints(
        minHeight: onSelected == null
            ? AppSizes.chipHeight
            : AppSizes.minimumTouchTarget,
      ),
      padding: AppInsets.chip,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: selected || !isDark ? AppColors.ink : AppColors.onDark,
        ),
      ),
    );

    if (onSelected == null) {
      return chip;
    }

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: () => onSelected!(!selected),
          child: chip,
        ),
      ),
    );
  }
}
