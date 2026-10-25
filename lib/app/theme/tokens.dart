import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF49CBEB);
  static const primaryContainer = Color(0xFF9EE3F6);
  static const accent = Color(0xFF7FF0CB);
  static const accentSoft = Color(0xFFC9F7E8);
  static const ink = Color(0xFF000000);
  static const inkSoft = Color(0xFF5B6168);
  static const background = Color(0xFFF4F5F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF1E1E1E);
  static const chipDark = Color(0xFF2E2E2E);
  static const onDark = Color(0xFFFFFFFF);
  static const warning = Color(0xFFF5A524);
  static const rating = Color(0xFFF5B83D);
  static const error = Color(0xFFE5484D);
  static const divider = Color(0xFFE6E8EA);
  static const shadow = Color(0x0F000000);
  static const stage1 = Color(0xFF9EE3F6);
  static const stage2 = Color(0xFFAEEBD6);
  static const stage3 = Color(0xFFFFD58A);
  static const stage4 = Color(0xFFFFB8C8);
  static const stage5 = Color(0xFFCCBCFF);
  static const stage1Soft = Color(0xFFDDF5FB);
  static const stage2Soft = Color(0xFFE0F7EF);
  static const stage3Soft = Color(0xFFFFF0D2);
  static const stage4Soft = Color(0xFFFFE6EC);
  static const stage5Soft = Color(0xFFEEE9FF);
}

abstract final class AppSpacing {
  static const s4 = 4.0;
  static const s6 = 6.0;
  static const s8 = 8.0;
  static const s10 = 10.0;
  static const s12 = 12.0;
  static const s14 = 14.0;
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
  static const bottomNavigationHeight = 76.0;
  static const navigationIcon = 24.0;
  static const buttonProgress = 20.0;
  static const stateIcon = 28.0;
  static const stateIconContainer = 64.0;
  static const statePreviewHeight = 260.0;
  static const homeSummaryCardWidth = 180.0;
  static const navigationAvatar = 32.0;
  static const mapMarker = 40.0;
  static const mapMarkerSelected = 52.0;
  static const mapMarkerBorder = 3.0;
  static const mapSheetHandleWidth = 48.0;
  static const mapSheetHandleHeight = 4.0;
  static const mapRouteWidth = 7.0;
  static const mapRouteBorderWidth = 11.0;
  static const routePanelHeight = 180.0;
  static const mapSheetInitial = 0.42;
  static const mapSheetMinimum = 0.16;
  static const mapSheetDetail = 0.65;
  static const mapSheetMaximum = 0.85;
  static const dialogMaxWidth = 420.0;
  static const progressStroke = 2.0;
  static const chipHeight = 36.0;
  static const customTagIcon = 14.0;
  static const customTagBorder = 2.0;
  static const customTagDashBorder = 1.5;
  static const profileAvatar = 84.0;
  static const profileBadge = 32.0;
  static const profileBadgeBorder = 3.0;
  static const profileBadgeIcon = 16.0;
  static const settingsIconCircle = 42.0;
  static const settingsRowHeight = 68.0;
  static const dayChipHeight = 44.0;
  static const stepperButton = 40.0;
  static const stepperValueWidth = 52.0;
  static const dividerThickness = 1.0;
  static const floatingButtonClearance = 96.0;
  static const stockBarHeight = 10.0;
  static const historyBadge = 44.0;
  static const historyRowHeight = 72.0;
  static const brewChartHeight = 140.0;
  static const chatAvatar = 30.0;
  static const chatSendButton = 52.0;
}

abstract final class AppInsets {
  static const screen = EdgeInsets.symmetric(
    horizontal: AppSpacing.s20,
    vertical: AppSpacing.s24,
  );
  static const card = EdgeInsets.all(AppSpacing.s20);
  static const mapListCard = EdgeInsets.all(AppSpacing.s12);
  static const input = EdgeInsets.symmetric(
    horizontal: AppSpacing.s16,
    vertical: AppSpacing.s16,
  );
  static const button = EdgeInsets.symmetric(horizontal: AppSpacing.s24);
  static const dialog = EdgeInsets.all(AppSpacing.s24);
  static const bottomNavigation = EdgeInsets.symmetric(
    horizontal: AppSpacing.s4,
    vertical: AppSpacing.s8,
  );
  static const bottomNavigationItem = EdgeInsets.all(AppSpacing.s4);
  static const settingsCard = EdgeInsets.symmetric(
    horizontal: AppSpacing.s16,
    vertical: AppSpacing.s4,
  );
  static const settingsBlock = EdgeInsets.all(AppSpacing.s16);
  static const chip = EdgeInsets.symmetric(
    horizontal: AppSpacing.s12,
    vertical: AppSpacing.s8,
  );
  static const statusPill = EdgeInsets.symmetric(
    horizontal: AppSpacing.s12,
    vertical: AppSpacing.s4,
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
