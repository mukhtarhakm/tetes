import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    required this.label,
    required this.items,
    required this.itemLabel,
    required this.value,
    required this.onChanged,
    this.hintText = 'Pilih',
    this.errorText,
    this.enabled = true,
    super.key,
  });

  final String label;
  final List<T> items;
  final String Function(T item) itemLabel;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String hintText;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: const BorderSide(color: AppColors.divider),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.s8),
        InputDecorator(
          isEmpty: value == null,
          decoration: InputDecoration(
            errorText: errorText,
            contentPadding: AppInsets.input,
            filled: true,
            fillColor: AppColors.surface,
            border: border,
            enabledBorder: border,
            focusedBorder: border.copyWith(
              borderSide: const BorderSide(color: AppColors.ink),
            ),
            errorBorder: border.copyWith(
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: border.copyWith(
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              hint: Text(
                hintText,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
              ),
              isExpanded: true,
              isDense: true,
              borderRadius: BorderRadius.circular(AppRadius.navigation),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.inkSoft,
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.ink),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(itemLabel(item), softWrap: false),
                    ),
                  )
                  .toList(),
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}
