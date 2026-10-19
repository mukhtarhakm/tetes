import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

abstract final class BrewStageColors {
  static Color forPosition(int position) {
    return switch (position) {
      1 => AppColors.stage1,
      2 => AppColors.stage2,
      3 => AppColors.stage3,
      4 => AppColors.stage4,
      5 => AppColors.stage5,
      _ => throw RangeError.range(position, 1, 5, 'position'),
    };
  }

  static Color softForPosition(int position) {
    return switch (position) {
      1 => AppColors.stage1Soft,
      2 => AppColors.stage2Soft,
      3 => AppColors.stage3Soft,
      4 => AppColors.stage4Soft,
      5 => AppColors.stage5Soft,
      _ => throw RangeError.range(position, 1, 5, 'position'),
    };
  }
}
