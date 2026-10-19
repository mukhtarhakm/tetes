import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

enum StatusPillVariant { synced, pending, error, warning }

class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, required this.variant, super.key});

  final String label;
  final StatusPillVariant variant;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = switch (variant) {
      StatusPillVariant.synced => AppColors.accent,
      StatusPillVariant.pending => AppColors.divider,
      StatusPillVariant.error => AppColors.error,
      StatusPillVariant.warning => AppColors.warning,
    };
    final foregroundColor = variant == StatusPillVariant.error
        ? AppColors.onDark
        : AppColors.ink;

    return Container(
      padding: AppInsets.statusPill,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: foregroundColor),
      ),
    );
  }
}
