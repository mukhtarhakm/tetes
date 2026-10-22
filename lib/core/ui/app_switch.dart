import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Sakelar bergaya Tetes: trek cyan saat aktif, abu muda saat mati, gagang putih.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    required this.value,
    required this.onChanged,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticLabel,
      child: Theme(
        data: theme.copyWith(
          switchTheme: SwitchThemeData(
            thumbColor: const WidgetStatePropertyAll(AppColors.surface),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.divider,
            ),
            trackOutlineColor: const WidgetStatePropertyAll(
              Colors.transparent,
            ),
          ),
        ),
        child: Switch(value: value, onChanged: onChanged),
      ),
    );
  }
}
