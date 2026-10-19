import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'app_button.dart';
import 'app_text_field.dart';

class AppInputDialog extends StatefulWidget {
  const AppInputDialog({
    required this.title,
    required this.fieldLabel,
    required this.primaryLabel,
    this.maxLength,
    super.key,
  });

  final String title;
  final String fieldLabel;
  final String primaryLabel;
  final int? maxLength;

  @override
  State<AppInputDialog> createState() => _AppInputDialogState();
}

class _AppInputDialogState extends State<AppInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.s20),
              AppTextField(
                controller: _controller,
                label: widget.fieldLabel,
                maxLength: widget.maxLength,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.s24),
              AppButton(
                label: widget.primaryLabel,
                onPressed: () => Navigator.of(context).pop(_controller.text),
              ),
              const SizedBox(height: AppSpacing.s8),
              AppButton(
                label: 'Batal',
                variant: AppButtonVariant.text,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
