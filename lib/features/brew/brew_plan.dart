enum Grind {
  sangatHalus('sangat_halus', 'Sangat halus'),
  halus('halus', 'Halus'),
  sedangHalus('sedang_halus', 'Sedang halus'),
  sedang('sedang', 'Sedang'),
  sedangKasar('sedang_kasar', 'Sedang kasar'),
  kasar('kasar', 'Kasar');

  const Grind(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static Grind? tryFromDatabase(String value) {
    for (final grind in values) {
      if (grind.databaseValue == value) {
        return grind;
      }
    }
    return null;
  }
}

enum BrewStageName {
  bloom('bloom', 'Bloom'),
  pouring2('pouring_2', 'Pouring 2'),
  pouring3('pouring_3', 'Pouring 3'),
  pouring4('pouring_4', 'Pouring 4'),
  pouring5('pouring_5', 'Pouring 5');

  const BrewStageName(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static BrewStageName? tryFromDatabase(String value) {
    for (final name in values) {
      if (name.databaseValue == value) {
        return name;
      }
    }
    return null;
  }

  static BrewStageName forPosition(int position) {
    if (position < 1 || position > values.length) {
      throw RangeError.range(position, 1, values.length, 'position');
    }
    return values[position - 1];
  }
}

class BrewStage {
  const BrewStage({
    required this.position,
    required this.name,
    required this.startSeconds,
    required this.durationSeconds,
    required this.gapAfterSeconds,
    required this.targetPourG,
  });

  final int position;
  final BrewStageName name;
  final int startSeconds;
  final int durationSeconds;
  final int gapAfterSeconds;
  final double targetPourG;

  int get endSeconds => startSeconds + durationSeconds;

  BrewStage copyWith({
    int? startSeconds,
    int? durationSeconds,
    int? gapAfterSeconds,
    double? targetPourG,
  }) {
    return BrewStage(
      position: position,
      name: name,
      startSeconds: startSeconds ?? this.startSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      gapAfterSeconds: gapAfterSeconds ?? this.gapAfterSeconds,
      targetPourG: targetPourG ?? this.targetPourG,
    );
  }
}

class BrewPlan {
  const BrewPlan({
    required this.beanId,
    required this.doseG,
    required this.ratio,
    required this.waterTempC,
    required this.grind,
    required this.pouringCount,
    required this.stages,
    this.fromBestBrew = false,
  });

  final String beanId;
  final double doseG;
  final double ratio;
  final int waterTempC;
  final Grind grind;
  final int pouringCount;
  final List<BrewStage> stages;
  final bool fromBestBrew;

  double get totalWaterG => doseG * ratio;

  int get totalTimeSeconds => stages.isEmpty ? 0 : stages.last.endSeconds;

  double cumulativeWaterAt(int stageIndex) {
    return stages
        .take(stageIndex + 1)
        .fold(0, (total, stage) => total + stage.targetPourG);
  }

  BrewPlan copyWith({
    double? doseG,
    double? ratio,
    int? waterTempC,
    Grind? grind,
    int? pouringCount,
    List<BrewStage>? stages,
    bool? fromBestBrew,
  }) {
    return BrewPlan(
      beanId: beanId,
      doseG: doseG ?? this.doseG,
      ratio: ratio ?? this.ratio,
      waterTempC: waterTempC ?? this.waterTempC,
      grind: grind ?? this.grind,
      pouringCount: pouringCount ?? this.pouringCount,
      stages: List.unmodifiable(stages ?? this.stages),
      fromBestBrew: fromBestBrew ?? this.fromBestBrew,
    );
  }
}
