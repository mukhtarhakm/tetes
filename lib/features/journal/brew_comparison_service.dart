import 'journal_model.dart';

abstract final class BrewComparisonService {
  /// Menghasilkan satu kalimat ringkasan perbandingan deterministik murni tanpa AI.
  /// Aturan:
  /// 1. Jika biji berbeda: sebut hanya skor dan tulis bahwa bijinya berbeda.
  /// 2. Jika tidak ada variabel yang berubah: "Pengaturan sama, skor X dan Y."
  /// 3. Variabel diperiksa dengan prioritas: suhu dan rasio didahulukan, lalu grind dan dosis (maksimal dua perubahan).
  /// 4. Format kalimat: "Skor [hasil] setelah [perubahan]."
  static String generateComparisonSummary({
    required BrewDetailData older,
    required BrewDetailData newer,
  }) {
    final olderScore = older.item.tasteScore;
    final newerScore = newer.item.tasteScore;
    final scoreDiff = newerScore - olderScore;

    // Aturan 1: Biji berbeda
    if (older.item.beanId != newer.item.beanId) {
      if (scoreDiff > 0) {
        return 'Biji berbeda. Skor naik $scoreDiff (dari $olderScore ke $newerScore).';
      } else if (scoreDiff < 0) {
        return 'Biji berbeda. Skor turun ${scoreDiff.abs()} (dari $olderScore ke $newerScore).';
      } else {
        return 'Biji berbeda. Skor sama-sama $olderScore.';
      }
    }

    // Kumpulkan perubahan variabel sesuai prioritas (suhu, rasio, grind, dosis)
    final changes = <String>[];

    // 1. Suhu (didahulukan)
    final tempDiff = newer.item.waterTempC - older.item.waterTempC;
    if (tempDiff > 0) {
      changes.add('suhu naik $tempDiff°C');
    } else if (tempDiff < 0) {
      changes.add('suhu turun ${tempDiff.abs()}°C');
    }

    // 2. Rasio (didahulukan)
    final ratioDiff = newer.item.ratio - older.item.ratio;
    if (ratioDiff.abs() > 0.0001) {
      if (ratioDiff > 0) {
        changes.add('rasio diperbesar');
      } else {
        changes.add('rasio diperkecil');
      }
    }

    // 3. Grind
    if (newer.item.grind != older.item.grind) {
      if (newer.item.grind.index > older.item.grind.index) {
        changes.add('grind lebih kasar');
      } else {
        changes.add('grind lebih halus');
      }
    }

    // 4. Dosis
    final doseDiff = newer.item.doseG - older.item.doseG;
    if (doseDiff.abs() > 0.0001) {
      final doseStr = doseDiff.abs() == doseDiff.abs().roundToDouble()
          ? doseDiff.abs().toStringAsFixed(0)
          : doseDiff.abs().toStringAsFixed(1);
      if (doseDiff > 0) {
        changes.add('dosis naik ${doseStr}g');
      } else {
        changes.add('dosis turun ${doseStr}g');
      }
    }

    // Aturan 2: Pengaturan sama
    if (changes.isEmpty) {
      return 'Pengaturan sama, skor $olderScore dan $newerScore.';
    }

    // Ambil maksimal dua perubahan yang paling diprioritaskan
    final selectedChanges = changes.take(2).toList();
    final changesText = selectedChanges.join(' dan ');

    final String scoreResult;
    if (scoreDiff > 0) {
      scoreResult = 'naik $scoreDiff';
    } else if (scoreDiff < 0) {
      scoreResult = 'turun ${scoreDiff.abs()}';
    } else {
      scoreResult = 'sama';
    }

    return 'Skor $scoreResult setelah $changesText.';
  }
}
