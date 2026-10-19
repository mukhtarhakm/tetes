import 'brew_plan.dart';

class BrewPlanException implements Exception {
  const BrewPlanException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract final class BrewValidation {
  static String? dose(double? value) {
    if (value == null || !value.isFinite) {
      return 'Dosis harus berupa angka.';
    }
    if (value < 5 || value > 60) {
      return 'Dosis harus antara 5 dan 60 gram.';
    }
    return null;
  }

  static String? ratio(double? value) {
    if (value == null || !value.isFinite) {
      return 'Rasio harus berupa angka.';
    }
    if (value < 10 || value > 20) {
      return 'Rasio harus antara 10 dan 20.';
    }
    final tenths = value * 10;
    if ((tenths - tenths.round()).abs() > 0.0000001) {
      return 'Rasio hanya boleh memakai satu angka desimal.';
    }
    return null;
  }

  static String? temperature(int? value) {
    if (value == null) {
      return 'Suhu harus berupa bilangan bulat.';
    }
    if (value < 80 || value > 100) {
      return 'Suhu harus antara 80 dan 100 °C.';
    }
    return null;
  }

  static String? pouringCount(int? value) {
    if (value == null || value < 1 || value > 5) {
      return 'Jumlah pouring harus antara 1 dan 5.';
    }
    return null;
  }

  static String? duration(int? value) {
    if (value == null || value < 5 || value > 120) {
      return 'Durasi tahap harus antara 5 dan 120 detik.';
    }
    return null;
  }

  static String? gap(int? value) {
    if (value == null || value < 0 || value > 60) {
      return 'Jeda harus antara 0 dan 60 detik.';
    }
    return null;
  }
}

abstract final class BrewCalculator {
  static const defaultDoseG = 15.0;
  static const defaultRatio = 16.0;
  static const defaultWaterTempC = 92;
  static const defaultGrind = Grind.sedang;
  static const defaultPouringCount = 3;
  static const defaultBloomDurationSeconds = 40;
  static const defaultPourDurationSeconds = 30;
  static const defaultGapSeconds = 5;

  static BrewPlan createDefault({
    required String beanId,
    double doseG = defaultDoseG,
    double ratio = defaultRatio,
    int waterTempC = defaultWaterTempC,
    Grind grind = defaultGrind,
    int pouringCount = defaultPouringCount,
  }) {
    _validateInputs(
      doseG: doseG,
      ratio: ratio,
      waterTempC: waterTempC,
      pouringCount: pouringCount,
    );

    final pours = calculateTargets(
      doseG: doseG,
      ratio: ratio,
      pouringCount: pouringCount,
    );

    return BrewPlan(
      beanId: beanId,
      doseG: doseG,
      ratio: ratio,
      waterTempC: waterTempC,
      grind: grind,
      pouringCount: pouringCount,
      stages: List.unmodifiable(_defaultStages(pours)),
    );
  }

  static List<double> calculateTargets({
    required double doseG,
    required double ratio,
    required int pouringCount,
  }) {
    if (!doseG.isFinite || !ratio.isFinite || pouringCount < 1) {
      throw const BrewPlanException('Data perhitungan tahap tidak valid.');
    }
    final totalWaterG = doseG * ratio;
    final pours = <double>[];
    if (pouringCount == 1) {
      pours.add(totalWaterG);
    } else {
      final bloomG = (doseG * 3).roundToDouble();
      if (bloomG >= totalWaterG) {
        throw const BrewPlanException(
          'Target bloom harus lebih kecil dari total air. Periksa dosis atau rasio.',
        );
      }
      pours.add(bloomG);
      final roundedFollowingPour = ((totalWaterG - bloomG) / (pouringCount - 1))
          .roundToDouble();
      for (var index = 1; index < pouringCount; index++) {
        final isLast = index == pouringCount - 1;
        final assigned = pours.fold<double>(0, (sum, value) => sum + value);
        pours.add(isLast ? totalWaterG - assigned : roundedFollowingPour);
      }
    }

    if (pours.any((value) => value <= 0)) {
      throw const BrewPlanException(
        'Target air tahap terakhir harus lebih dari 0 gram.',
      );
    }

    return List.unmodifiable(pours);
  }

  static BrewPlan updateParameters(
    BrewPlan plan, {
    double? doseG,
    double? ratio,
    int? waterTempC,
    Grind? grind,
    int? pouringCount,
  }) {
    final nextDose = doseG ?? plan.doseG;
    final nextRatio = ratio ?? plan.ratio;
    final nextTemperature = waterTempC ?? plan.waterTempC;
    final nextGrind = grind ?? plan.grind;
    final nextPouringCount = pouringCount ?? plan.pouringCount;
    final shouldRebuildStages =
        nextDose != plan.doseG ||
        nextRatio != plan.ratio ||
        nextPouringCount != plan.pouringCount;

    if (shouldRebuildStages) {
      return createDefault(
        beanId: plan.beanId,
        doseG: nextDose,
        ratio: nextRatio,
        waterTempC: nextTemperature,
        grind: nextGrind,
        pouringCount: nextPouringCount,
      );
    }

    _validateInputs(
      doseG: nextDose,
      ratio: nextRatio,
      waterTempC: nextTemperature,
      pouringCount: nextPouringCount,
    );
    return plan.copyWith(
      waterTempC: nextTemperature,
      grind: nextGrind,
      fromBestBrew: false,
    );
  }

  static BrewPlan updateDuration(
    BrewPlan plan, {
    required int stageIndex,
    required int durationSeconds,
  }) {
    final error = BrewValidation.duration(durationSeconds);
    if (error != null) {
      throw BrewPlanException(error);
    }
    final stages = List<BrewStage>.of(plan.stages);
    stages[stageIndex] = stages[stageIndex].copyWith(
      durationSeconds: durationSeconds,
    );
    return plan.copyWith(
      stages: _recalculateStarts(stages),
      fromBestBrew: false,
    );
  }

  static BrewPlan updateGap(
    BrewPlan plan, {
    required int stageIndex,
    required int gapSeconds,
  }) {
    if (stageIndex >= plan.stages.length - 1) {
      throw const BrewPlanException('Tahap terakhir tidak memiliki jeda.');
    }
    final error = BrewValidation.gap(gapSeconds);
    if (error != null) {
      throw BrewPlanException(error);
    }
    final stages = List<BrewStage>.of(plan.stages);
    stages[stageIndex] = stages[stageIndex].copyWith(
      gapAfterSeconds: gapSeconds,
    );
    return plan.copyWith(
      stages: _recalculateStarts(stages),
      fromBestBrew: false,
    );
  }

  static BrewPlan updateTargetPour(
    BrewPlan plan, {
    required int stageIndex,
    required double targetPourG,
  }) {
    if (stageIndex >= plan.stages.length - 1) {
      throw const BrewPlanException(
        'Target tahap terakhir dihitung otomatis sebagai sisa.',
      );
    }
    if (!targetPourG.isFinite || targetPourG <= 0) {
      throw const BrewPlanException('Target air harus lebih dari 0 gram.');
    }
    final stages = List<BrewStage>.of(plan.stages);
    stages[stageIndex] = stages[stageIndex].copyWith(targetPourG: targetPourG);
    final assignedBeforeLast = stages
        .take(stages.length - 1)
        .fold<double>(0, (sum, stage) => sum + stage.targetPourG);
    final lastTarget = plan.totalWaterG - assignedBeforeLast;
    if (lastTarget <= 0) {
      throw const BrewPlanException(
        'Perubahan ditolak: target air tahap terakhir harus lebih dari 0 gram.',
      );
    }
    stages[stages.length - 1] = stages.last.copyWith(targetPourG: lastTarget);
    return plan.copyWith(stages: stages, fromBestBrew: false);
  }

  static void validatePlan(BrewPlan plan) {
    _validateInputs(
      doseG: plan.doseG,
      ratio: plan.ratio,
      waterTempC: plan.waterTempC,
      pouringCount: plan.pouringCount,
    );
    if (plan.stages.length != plan.pouringCount) {
      throw const BrewPlanException(
        'Jumlah tahap tidak sesuai jumlah pouring.',
      );
    }
    var cumulativeWater = 0.0;
    for (var index = 0; index < plan.stages.length; index++) {
      final stage = plan.stages[index];
      if (stage.position != index + 1 ||
          stage.name != BrewStageName.forPosition(index + 1)) {
        throw const BrewPlanException('Urutan atau nama tahap tidak valid.');
      }
      final durationError = BrewValidation.duration(stage.durationSeconds);
      if (durationError != null) {
        throw BrewPlanException(durationError);
      }
      if (stage.targetPourG <= 0 || !stage.targetPourG.isFinite) {
        throw const BrewPlanException(
          'Target air tahap harus lebih dari 0 gram.',
        );
      }
      if (index == 0 && stage.startSeconds != 0) {
        throw const BrewPlanException(
          'Tahap pertama harus dimulai pada detik 0.',
        );
      }
      if (index < plan.stages.length - 1) {
        final gapError = BrewValidation.gap(stage.gapAfterSeconds);
        if (gapError != null) {
          throw BrewPlanException(gapError);
        }
        final next = plan.stages[index + 1];
        if (next.startSeconds != stage.endSeconds + stage.gapAfterSeconds) {
          throw const BrewPlanException(
            'Waktu tahap tidak boleh tumpang tindih.',
          );
        }
      } else if (stage.gapAfterSeconds != 0) {
        throw const BrewPlanException('Tahap terakhir tidak memiliki jeda.');
      }
      cumulativeWater += stage.targetPourG;
    }
    if ((cumulativeWater - plan.totalWaterG).abs() > 0.000001) {
      throw const BrewPlanException(
        'Target kumulatif terakhir harus sama dengan total air.',
      );
    }
  }

  static List<BrewStage> _defaultStages(List<double> pours) {
    final stages = <BrewStage>[];
    var startSeconds = 0;
    for (var index = 0; index < pours.length; index++) {
      final isLast = index == pours.length - 1;
      final duration = index == 0
          ? defaultBloomDurationSeconds
          : defaultPourDurationSeconds;
      final gap = isLast ? 0 : defaultGapSeconds;
      stages.add(
        BrewStage(
          position: index + 1,
          name: BrewStageName.forPosition(index + 1),
          startSeconds: startSeconds,
          durationSeconds: duration,
          gapAfterSeconds: gap,
          targetPourG: pours[index],
        ),
      );
      startSeconds += duration + gap;
    }
    return stages;
  }

  static List<BrewStage> _recalculateStarts(List<BrewStage> stages) {
    final result = <BrewStage>[];
    var startSeconds = 0;
    for (final stage in stages) {
      final updated = stage.copyWith(startSeconds: startSeconds);
      result.add(updated);
      startSeconds = updated.endSeconds + updated.gapAfterSeconds;
    }
    return List.unmodifiable(result);
  }

  static void _validateInputs({
    required double doseG,
    required double ratio,
    required int waterTempC,
    required int pouringCount,
  }) {
    final errors = [
      BrewValidation.dose(doseG),
      BrewValidation.ratio(ratio),
      BrewValidation.temperature(waterTempC),
      BrewValidation.pouringCount(pouringCount),
    ].whereType<String>();
    if (errors.isNotEmpty) {
      throw BrewPlanException(errors.first);
    }
  }
}
