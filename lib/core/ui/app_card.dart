import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

enum AppCardVariant { standard, featured, tinted }

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.variant = AppCardVariant.standard,
    this.padding = AppInsets.card,
    this.backgroundColor,
    super.key,
  });

  final Widget child;
  final AppCardVariant variant;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final resolvedBackgroundColor =
        backgroundColor ??
        switch (variant) {
          AppCardVariant.standard => colors.surface,
          AppCardVariant.featured => AppColors.ink,
          AppCardVariant.tinted => colors.primaryContainer,
        };
    final foregroundColor = switch (variant) {
      AppCardVariant.featured => AppColors.onDark,
      AppCardVariant.standard || AppCardVariant.tinted => AppColors.ink,
    };

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedBackgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: foregroundColor,
            displayColor: foregroundColor,
          ),
          iconTheme: IconThemeData(color: foregroundColor),
        ),
        child: DefaultTextStyle.merge(
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: foregroundColor),
          child: child,
        ),
      ),
    );
  }
}
