import 'package:flutter/material.dart';

import 'tokens.dart';

abstract final class AppTheme {
  static const fontFamily = 'Plus Jakarta Sans';

  static final TextTheme _textTheme =
      const TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      ).apply(
        fontFamily: fontFamily,
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      );

  static final ColorScheme _lightColorScheme = const ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: AppColors.ink,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.accent,
    onSecondary: AppColors.ink,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    error: AppColors.error,
    onError: AppColors.surface,
    outline: AppColors.divider,
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: fontFamily,
    colorScheme: _lightColorScheme,
    textTheme: _textTheme,
    scaffoldBackgroundColor: AppColors.background,
    dividerColor: AppColors.divider,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: _textTheme.titleLarge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: AppInsets.input,
      hintStyle: _textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
      errorStyle: _textTheme.bodySmall?.copyWith(color: AppColors.error),
      border: _inputBorder(AppColors.divider),
      enabledBorder: _inputBorder(AppColors.divider),
      focusedBorder: _inputBorder(AppColors.ink),
      errorBorder: _inputBorder(AppColors.error),
      focusedErrorBorder: _inputBorder(AppColors.error),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: _textTheme.bodyLarge?.copyWith(color: AppColors.onDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
    ),
  );

  static OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.navigation),
      borderSide: BorderSide(color: color),
    );
  }
}
