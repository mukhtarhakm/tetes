import '../beans/bean_model.dart';
import '../brew/brew_plan.dart';

Map<String, Object?> buildChatContext({
  required Bean bean,
  required BrewPlan? bestPlan,
  required List<Map<String, Object?>> recentBrews,
}) => {
  'bean': {
    'name': bean.name,
    'species': bean.species.databaseValue,
    if (bean.roastLevel != null) 'roast_level': bean.roastLevel!.databaseValue,
    'remaining_stock_g': bean.remainingStockG.clamp(0, 1000000),
    if (bestPlan != null)
      'best_settings': {
        'dose_g': bestPlan.doseG,
        'ratio': bestPlan.ratio,
        'water_temp_c': bestPlan.waterTempC,
        'grind': bestPlan.grind.databaseValue,
      },
  },
  'recent_brews': recentBrews
      .take(5)
      .map(
        (row) => {
          'brewed_at_utc': row['brewed_at_utc'],
          'dose_g': row['dose_g'],
          'ratio': row['ratio'],
          'water_temp_c': row['water_temp_c'],
          'grind': row['grind'],
          'taste_score': row['taste_score'],
          'taste_tags': row['taste_tags'],
        },
      )
      .toList(growable: false),
};
