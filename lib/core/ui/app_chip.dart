import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    this.icon,
    this.selected = false,
    this.onSelected,
    this.onDeleted,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = selected
        ? AppColors.primary
        : isDark
        ? AppColors.chipDark
        : AppColors.surface;
    final foregroundColor = selected || !isDark
        ? AppColors.ink
        : AppColors.onDark;
    final isInteractive = onSelected != null || onDeleted != null;
    final chip = AnimatedContainer(
      duration: AppDurations.feedback,
      constraints: BoxConstraints(
        minHeight: !isInteractive
            ? AppSizes.chipHeight
            : AppSizes.minimumTouchTarget,
      ),
      padding: AppInsets.chip,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: !selected && !isDark
            ? Border.all(color: AppColors.divider)
            : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.navigationIcon, color: foregroundColor),
            const SizedBox(width: AppSpacing.s8),
          ],
          Text(
            label,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: foregroundColor),
          ),
          if (onDeleted != null) ...[
            const SizedBox(width: AppSpacing.s8),
            Icon(
              Icons.close_rounded,
              size: AppSizes.navigationIcon,
              color: foregroundColor,
            ),
          ],
        ],
      ),
    );

    if (!isInteractive) {
      return chip;
    }

    return Semantics(
      button: true,
      selected: onSelected == null ? null : selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onDeleted ?? () => onSelected!(!selected),
          child: chip,
        ),
      ),
    );
  }
}
