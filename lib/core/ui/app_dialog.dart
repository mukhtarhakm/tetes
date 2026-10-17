import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'app_button.dart';

class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimaryPressed,
    this.secondaryLabel,
    this.onSecondaryPressed,
    super.key,
  });

  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.dialogMaxWidth),
        child: Padding(
          padding: AppInsets.dialog,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.s12),
              Text(message, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.s24),
              AppButton(label: primaryLabel, onPressed: onPrimaryPressed),
              if (secondaryLabel != null) ...[
                const SizedBox(height: AppSpacing.s8),
                AppButton(
                  label: secondaryLabel!,
                  onPressed: onSecondaryPressed,
                  variant: AppButtonVariant.text,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
