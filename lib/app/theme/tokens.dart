import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF49CBEB);
  static const primaryContainer = Color(0xFF9EE3F6);
  static const accent = Color(0xFF7FF0CB);
  static const ink = Color(0xFF000000);
  static const inkSoft = Color(0xFF5B6168);
  static const background = Color(0xFFF4F5F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const chipDark = Color(0xFF2E2E2E);
  static const onDark = Color(0xFFFFFFFF);
  static const warning = Color(0xFFF5A524);
  static const error = Color(0xFFE5484D);
  static const divider = Color(0xFFE6E8EA);
  static const shadow = Color(0x0F000000);
}

abstract final class AppSpacing {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const s48 = 48.0;
}

abstract final class AppRadius {
  static const small = 12.0;
  static const navigation = 16.0;
  static const innerCard = 20.0;
  static const card = 24.0;
  static const pill = 999.0;
}

abstract final class AppSizes {
  static const minimumTouchTarget = 48.0;
  static const bottomNavigationHeight = 64.0;
  static const navigationIcon = 24.0;
  static const buttonProgress = 20.0;
  static const stateIcon = 28.0;
  static const stateIconContainer = 64.0;
  static const statePreviewHeight = 260.0;
  static const dialogMaxWidth = 420.0;
  static const progressStroke = 2.0;
}

abstract final class AppInsets {
  static const screen = EdgeInsets.symmetric(
    horizontal: AppSpacing.s20,
    vertical: AppSpacing.s24,
  );
  static const card = EdgeInsets.all(AppSpacing.s20);
  static const input = EdgeInsets.symmetric(
    horizontal: AppSpacing.s16,
    vertical: AppSpacing.s16,
  );
  static const button = EdgeInsets.symmetric(horizontal: AppSpacing.s24);
  static const dialog = EdgeInsets.all(AppSpacing.s24);
  static const bottomNavigation = EdgeInsets.symmetric(
    horizontal: AppSpacing.s12,
    vertical: AppSpacing.s8,
  );
  static const bottomNavigationItem = EdgeInsets.symmetric(
    horizontal: AppSpacing.s12,
    vertical: AppSpacing.s8,
  );
}

abstract final class AppShadows {
  static const card = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: AppSpacing.s24,
      offset: Offset(0, AppSpacing.s8),
    ),
  ];
}

abstract final class AppDurations {
  static const feedback = Duration(milliseconds: 200);
}
