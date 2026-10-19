import 'package:sqflite/sqflite.dart';

import '../../features/brew/brew_calculator.dart';
import '../../features/brew/brew_plan.dart';

class BrewRepository {
  const BrewRepository(this._database);

  final Database _database;

  Future<BrewPlan?> findBestPlan({
    required String userId,
    required String beanId,
    required String bestBrewId,
  }) async {
    final brewRows = await _database.query(
      'brews',
      columns: ['id', 'dose_g', 'ratio', 'water_temp_c', 'grind'],
      where: 'id = ? AND user_id = ? AND bean_id = ? AND status = ?',
      whereArgs: [bestBrewId, userId, beanId, 'aktif'],
      limit: 1,
    );
    if (brewRows.isEmpty) {
      return null;
    }

    final stageRows = await _database.query(
      'brew_stages',
      columns: [
        'position',
        'name',
        'target_start_s',
        'target_duration_s',
        'target_water_cum_g',
        'target_pour_g',
      ],
      where: 'brew_id = ?',
      whereArgs: [bestBrewId],
      orderBy: 'position ASC',
    );

    try {
      final row = brewRows.single;
      final grind = Grind.tryFromDatabase(row['grind']! as String);
      if (grind == null || stageRows.isEmpty || stageRows.length > 5) {
        return null;
      }
      final stages = <BrewStage>[];
      var cumulativeWater = 0.0;
      for (var index = 0; index < stageRows.length; index++) {
        final stageRow = stageRows[index];
        final position = (stageRow['position']! as num).toInt();
        final name = BrewStageName.tryFromDatabase(stageRow['name']! as String);
        if (name == null) {
          return null;
        }
        final duration = (stageRow['target_duration_s']! as num).toInt();
        final start = (stageRow['target_start_s']! as num).toInt();
        final targetPour = (stageRow['target_pour_g']! as num).toDouble();
        cumulativeWater += targetPour;
        final storedCumulative = (stageRow['target_water_cum_g']! as num)
            .toDouble();
        if ((storedCumulative - cumulativeWater).abs() > 0.000001) {
          return null;
        }
        final gapAfter = index == stageRows.length - 1
            ? 0
            : (stageRows[index + 1]['target_start_s']! as num).toInt() -
                  (start + duration);
        stages.add(
          BrewStage(
            position: position,
            name: name,
            startSeconds: start,
            durationSeconds: duration,
            gapAfterSeconds: gapAfter,
            targetPourG: targetPour,
          ),
        );
      }

      final plan = BrewPlan(
        beanId: beanId,
        doseG: (row['dose_g']! as num).toDouble(),
        ratio: (row['ratio']! as num).toDouble(),
        waterTempC: (row['water_temp_c']! as num).toInt(),
        grind: grind,
        pouringCount: stages.length,
        stages: List.unmodifiable(stages),
        fromBestBrew: true,
      );
      BrewCalculator.validatePlan(plan);
      return plan;
    } on BrewPlanException {
      return null;
    } on FormatException {
      return null;
    } on StateError {
      return null;
    } on TypeError {
      return null;
    }
  }
}
