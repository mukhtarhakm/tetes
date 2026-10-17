import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

enum AppButtonVariant { primary, secondary, text }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.expand = true,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool expand;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabledOnPressed = isLoading ? null : onPressed;
    final foregroundColor = _foregroundColor(isDark);
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    final child = isLoading
        ? SizedBox.square(
            dimension: AppSizes.buttonProgress,
            child: CircularProgressIndicator(
              strokeWidth: AppSizes.progressStroke,
              color: foregroundColor,
            ),
          )
        : icon == null
        ? Text(label)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(width: AppSpacing.s8),
              Text(label),
            ],
          );

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: enabledOnPressed,
        style: _buttonStyle(
          backgroundColor: isDark ? AppColors.surface : AppColors.ink,
          foregroundColor: isDark ? AppColors.ink : AppColors.onDark,
          textStyle: labelStyle,
        ),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: enabledOnPressed,
        style: _buttonStyle(
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
          foregroundColor: isDark ? AppColors.onDark : AppColors.ink,
          side: const BorderSide(color: AppColors.divider),
          textStyle: labelStyle,
        ),
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: enabledOnPressed,
        style: _buttonStyle(
          foregroundColor: isDark ? AppColors.onDark : AppColors.ink,
          textStyle: labelStyle,
        ),
        child: child,
      ),
    };

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  Color _foregroundColor(bool isDark) {
    return switch (variant) {
      AppButtonVariant.primary => isDark ? AppColors.ink : AppColors.onDark,
      AppButtonVariant.secondary ||
      AppButtonVariant.text => isDark ? AppColors.onDark : AppColors.ink,
    };
  }

  ButtonStyle _buttonStyle({
    Color? backgroundColor,
    required Color foregroundColor,
    BorderSide? side,
    TextStyle? textStyle,
  }) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(AppSizes.minimumTouchTarget, AppSizes.minimumTouchTarget),
      ),
      padding: const WidgetStatePropertyAll(AppInsets.button),
      backgroundColor: WidgetStatePropertyAll(backgroundColor),
      foregroundColor: WidgetStatePropertyAll(foregroundColor),
      side: WidgetStatePropertyAll(side),
      textStyle: WidgetStatePropertyAll(textStyle),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      animationDuration: AppDurations.feedback,
    );
  }
}
