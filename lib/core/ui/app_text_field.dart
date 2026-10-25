import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/tokens.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    this.controller,
    this.label,
    this.hintText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.isSearch = false,
    this.obscureText = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.maxLengthEnforcement,
    super.key,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hintText;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool isSearch;
  final bool obscureText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;

  @override
  Widget build(BuildContext context) {
    final radius = isSearch ? AppRadius.pill : AppRadius.navigation;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: AppColors.divider),
    );
    final field = TextFormField(
      controller: controller,
      obscureText: obscureText,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      maxLengthEnforcement: maxLengthEnforcement,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        errorText: errorText,
        prefixIcon: isSearch || prefixIcon != null
            ? Icon(prefixIcon ?? Icons.search_rounded)
            : null,
        suffixIcon: suffixIcon,
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
    );

    if (label == null) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.s8),
        field,
      ],
    );
  }
}
