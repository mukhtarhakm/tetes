import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/brew/brew_plan.dart';
import 'package:tetes/features/journal/brew_comparison_service.dart';
import 'package:tetes/features/journal/journal_model.dart';

void main() {
  BrewDetailData makeDetail({
    String beanId = 'bean-1',
    double doseG = 15.0,
    double ratio = 16.0,
    int waterTempC = 92,
    Grind grind = Grind.sedang,
    int tasteScore = 3,
  }) {
    return BrewDetailData(
      item: BrewJournalItem(
        id: 'brew-id',
        userId: 'user-1',
        seq: 1,
        beanId: beanId,
        beanName: 'Biji Uji',
        isBestBrew: false,
        brewedAtUtc: '2026-10-18T10:00:00Z',
        doseG: doseG,
        ratio: ratio,
        waterTempC: waterTempC,
        grind: grind,
        totalTimeS: 180,
        tasteScore: tasteScore,
        tasteTags: const ['asam'],
        status: 'aktif',
        syncStatus: 'synced',
        hash: 'hash',
      ),
      prevHash: '0',
      createdAt: '2026-10-18T10:00:00Z',
      roasteryNotesTags: const [],
      isBeanArchived: false,
      stages: const [],
    );
  }

  group('BrewComparisonService', () {
    test('suhu turun dan rasio diperkecil, skor naik', () {
      final older = makeDetail(waterTempC: 94, ratio: 16.0, tasteScore: 3);
      final newer = makeDetail(waterTempC: 92, ratio: 15.0, tasteScore: 4);

      final summary = BrewComparisonService.generateComparisonSummary(
        older: older,
        newer: newer,
      );

      expect(summary, 'Skor naik 1 setelah suhu turun 2°C dan rasio diperkecil.');
    });

    test('suhu naik dan dosis naik, skor turun', () {
      final older = makeDetail(waterTempC: 90, doseG: 15.0, tasteScore: 5);
      final newer = makeDetail(waterTempC: 93, doseG: 18.0, tasteScore: 3);

      final summary = BrewComparisonService.generateComparisonSummary(
        older: older,
        newer: newer,
      );

      expect(summary, 'Skor turun 2 setelah suhu naik 3°C dan dosis naik 3g.');
    });

    test('grind lebih halus saja yang berubah, skor sama', () {
      final older = makeDetail(grind: Grind.sedang, tasteScore: 4);
      final newer = makeDetail(grind: Grind.halus, tasteScore: 4);

      final summary = BrewComparisonService.generateComparisonSummary(
        older: older,
        newer: newer,
      );

      expect(summary, 'Skor sama setelah grind lebih halus.');
    });

    test('maksimal 2 variabel yang disebut (suhu dan rasio didahulukan)', () {
      // Ubah suhu, rasio, grind, dan dosis sekaligus
      final older = makeDetail(
        waterTempC: 92,
        ratio: 16.0,
        grind: Grind.sedang,
        doseG: 15.0,
        tasteScore: 2,
      );
      final newer = makeDetail(
        waterTempC: 90,
        ratio: 15.0,
        grind: Grind.kasar,
        doseG: 18.0,
        tasteScore: 4,
      );

      final summary = BrewComparisonService.generateComparisonSummary(
        older: older,
        newer: newer,
      );

      // Hanya suhu dan rasio yang masuk ringkasan
      expect(summary, 'Skor naik 2 setelah suhu turun 2°C dan rasio diperkecil.');
    });

    test('pengaturan sama menyebut skor kedua seduhan', () {
      final older = makeDetail(tasteScore: 3);
      final newer = makeDetail(tasteScore: 5);

      final summary = BrewComparisonService.generateComparisonSummary(
        older: older,
        newer: newer,
      );

      expect(summary, 'Pengaturan sama, skor 3 dan 5.');
    });

    test('biji berbeda menyebut biji berbeda dan perubahan skor', () {
      final older = makeDetail(beanId: 'bean-A', tasteScore: 3);
      final newer = makeDetail(beanId: 'bean-B', tasteScore: 4);

      final summary = BrewComparisonService.generateComparisonSummary(
        older: older,
        newer: newer,
      );

      expect(summary, 'Biji berbeda. Skor naik 1 (dari 3 ke 4).');
    });

    test('biji berbeda dengan skor sama', () {
      final older = makeDetail(beanId: 'bean-A', tasteScore: 4);
      final newer = makeDetail(beanId: 'bean-B', tasteScore: 4);

      final summary = BrewComparisonService.generateComparisonSummary(
        older: older,
        newer: newer,
      );

      expect(summary, 'Biji berbeda. Skor sama-sama 4.');
    });
  });
}
