import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/brew_plan.dart';

void main() {
  group('BrewCalculator.createDefault', () {
    test('bloom adalah tiga kali dosis dan sisa dibagi rata', () {
      final plan = BrewCalculator.createDefault(
        beanId: 'bean-1',
        doseG: 15,
        ratio: 16,
        pouringCount: 3,
      );

      expect(plan.totalWaterG, 240);
      expect(plan.stages.map((stage) => stage.targetPourG), [45, 98, 97]);
      expect(plan.stages.first.name, BrewStageName.bloom);
      expect(plan.stages.last.name, BrewStageName.pouring3);
      expect(plan.cumulativeWaterAt(2), 240);
    });

    test('tahap terakhir menyerap sisa pembulatan total tidak bulat', () {
      final plan = BrewCalculator.createDefault(
        beanId: 'bean-1',
        doseG: 15,
        ratio: 16.5,
        pouringCount: 3,
      );

      expect(plan.totalWaterG, 247.5);
      expect(plan.stages[0].targetPourG, 45);
      expect(plan.stages[1].targetPourG, 101);
      expect(plan.stages[2].targetPourG, 101.5);
      expect(plan.cumulativeWaterAt(2), 247.5);
    });

    test('n = 1 membuat satu tahap bloom berisi seluruh air', () {
      final plan = BrewCalculator.createDefault(
        beanId: 'bean-1',
        doseG: 15,
        ratio: 16,
        pouringCount: 1,
      );

      expect(plan.stages, hasLength(1));
      expect(plan.stages.single.name.databaseValue, 'bloom');
      expect(plan.stages.single.targetPourG, 240);
      expect(plan.stages.single.gapAfterSeconds, 0);
    });

    test('bloom yang mencapai total air ditolak dengan pesan jelas', () {
      expect(
        () => BrewCalculator.createDefault(
          beanId: 'bean-1',
          doseG: 60,
          ratio: 10,
          pouringCount: 5,
        ),
        returnsNormally,
      );

      expect(
        () => BrewCalculator.calculateTargets(
          doseG: 15,
          ratio: 3,
          pouringCount: 3,
        ),
        throwsA(
          isA<BrewPlanException>().having(
            (error) => error.message,
            'message',
            contains('Target bloom harus lebih kecil dari total air'),
          ),
        ),
      );
    });

    test('jadwal bawaan tidak tumpang tindih', () {
      final plan = BrewCalculator.createDefault(
        beanId: 'bean-1',
        pouringCount: 5,
      );

      for (var index = 1; index < plan.stages.length; index++) {
        final previous = plan.stages[index - 1];
        expect(
          plan.stages[index].startSeconds,
          previous.endSeconds + previous.gapAfterSeconds,
        );
      }
      expect(() => BrewCalculator.validatePlan(plan), returnsNormally);
    });
  });

  group('pengeditan', () {
    test('tahap terakhir otomatis menyerap perubahan target air', () {
      final plan = BrewCalculator.createDefault(
        beanId: 'bean-1',
        doseG: 15,
        ratio: 16,
        pouringCount: 3,
      );

      final edited = BrewCalculator.updateTargetPour(
        plan,
        stageIndex: 1,
        targetPourG: 120,
      );

      expect(edited.stages.map((stage) => stage.targetPourG), [45, 120, 75]);
      expect(edited.cumulativeWaterAt(2), 240);
    });

    test('target yang membuat tahap terakhir tidak positif ditolak', () {
      final plan = BrewCalculator.createDefault(
        beanId: 'bean-1',
        doseG: 15,
        ratio: 16,
        pouringCount: 3,
      );

      expect(
        () => BrewCalculator.updateTargetPour(
          plan,
          stageIndex: 1,
          targetPourG: 195,
        ),
        throwsA(
          isA<BrewPlanException>().having(
            (error) => error.message,
            'message',
            'Perubahan ditolak: target air tahap terakhir harus lebih dari 0 gram.',
          ),
        ),
      );
    });

    test('durasi dan jeda mengatur ulang waktu mulai tanpa tumpang tindih', () {
      var plan = BrewCalculator.createDefault(beanId: 'bean-1');
      plan = BrewCalculator.updateDuration(
        plan,
        stageIndex: 0,
        durationSeconds: 55,
      );
      plan = BrewCalculator.updateGap(plan, stageIndex: 0, gapSeconds: 12);

      expect(plan.stages[1].startSeconds, 67);
      expect(plan.stages[2].startSeconds, 102);
      expect(() => BrewCalculator.validatePlan(plan), returnsNormally);
    });

    test('perubahan dosis membuat ulang tahap dari nilai bawaan', () {
      var plan = BrewCalculator.createDefault(beanId: 'bean-1');
      plan = BrewCalculator.updateDuration(
        plan,
        stageIndex: 0,
        durationSeconds: 75,
      );
      plan = BrewCalculator.updateTargetPour(
        plan,
        stageIndex: 0,
        targetPourG: 60,
      );

      final rebuilt = BrewCalculator.updateParameters(plan, doseG: 20);

      expect(rebuilt.stages.first.durationSeconds, 40);
      expect(rebuilt.stages.first.targetPourG, 60);
      expect(rebuilt.stages[1].startSeconds, 45);
      expect(rebuilt.fromBestBrew, isFalse);
    });
  });

  group('validasi', () {
    test('batas dosis, rasio, suhu, dan pouring diterapkan', () {
      expect(BrewValidation.dose(4.9), isNotNull);
      expect(BrewValidation.dose(5), isNull);
      expect(BrewValidation.dose(60), isNull);
      expect(BrewValidation.dose(60.1), isNotNull);
      expect(BrewValidation.ratio(9.9), isNotNull);
      expect(BrewValidation.ratio(10), isNull);
      expect(BrewValidation.ratio(16.5), isNull);
      expect(BrewValidation.ratio(16.55), contains('satu angka desimal'));
      expect(BrewValidation.ratio(20), isNull);
      expect(BrewValidation.ratio(20.1), isNotNull);
      expect(BrewValidation.temperature(79), isNotNull);
      expect(BrewValidation.temperature(80), isNull);
      expect(BrewValidation.temperature(100), isNull);
      expect(BrewValidation.temperature(101), isNotNull);
      expect(BrewValidation.pouringCount(0), isNotNull);
      expect(BrewValidation.pouringCount(1), isNull);
      expect(BrewValidation.pouringCount(5), isNull);
      expect(BrewValidation.pouringCount(6), isNotNull);
    });

    test('batas durasi dan jeda diterapkan', () {
      expect(BrewValidation.duration(4), isNotNull);
      expect(BrewValidation.duration(5), isNull);
      expect(BrewValidation.duration(120), isNull);
      expect(BrewValidation.duration(121), isNotNull);
      expect(BrewValidation.gap(-1), isNotNull);
      expect(BrewValidation.gap(0), isNull);
      expect(BrewValidation.gap(60), isNull);
      expect(BrewValidation.gap(61), isNotNull);
    });
  });

  test('nilai enum database persis sesuai DATA_MODEL', () {
    expect(Grind.values.map((value) => value.databaseValue), [
      'sangat_halus',
      'halus',
      'sedang_halus',
      'sedang',
      'sedang_kasar',
      'kasar',
    ]);
    expect(BrewStageName.values.map((value) => value.databaseValue), [
      'bloom',
      'pouring_2',
      'pouring_3',
      'pouring_4',
      'pouring_5',
    ]);
  });
}
