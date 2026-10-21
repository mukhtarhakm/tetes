import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

class FocusDarkTheme extends StatelessWidget {
  const FocusDarkTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = Theme.of(context);
    return Theme(
      data: current.copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.surfaceDark,
        colorScheme: current.colorScheme.copyWith(
          brightness: Brightness.dark,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.onDark,
          primary: AppColors.primary,
          onPrimary: AppColors.ink,
        ),
        textTheme: current.textTheme.apply(
          bodyColor: AppColors.onDark,
          displayColor: AppColors.onDark,
        ),
        appBarTheme: current.appBarTheme.copyWith(
          backgroundColor: AppColors.surfaceDark,
          foregroundColor: AppColors.onDark,
        ),
      ),
      child: child,
    );
  }
}
