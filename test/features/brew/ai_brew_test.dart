import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/brew/ai_brew.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/brew_plan.dart';
import 'package:tetes/features/brew/brew_session_result.dart';
import 'package:tetes/features/journal/journal_model.dart';

void main() {
  final defaultPlan = BrewCalculator.createDefault(beanId: 'bean-1');

  test('rekomendasi valid menjadi rencana lokal', () {
    final advice = AiBrew.recommendationFromResponse(
      fallback: defaultPlan,
      requestedPouringCount: 3,
      response: _recommendation(),
    );
    expect(advice.usedFallback, isFalse);
    expect(advice.plan.stages.map((item) => item.targetPourG), [45, 98, 97]);
    expect(() => BrewCalculator.validatePlan(advice.plan), returnsNormally);
  });

  test(
    'hasil yang sah di server tetapi tidak valid di form memakai fallback',
    () {
      final gap = _recommendation();
      (gap['stages'] as List<Map<String, dynamic>>)[1]['start_s'] = 41;
      final result = AiBrew.recommendationFromResponse(
        fallback: defaultPlan,
        requestedPouringCount: 3,
        response: gap,
      );
      expect(result.usedFallback, isTrue);
      expect(result.plan, same(defaultPlan));
      expect(result.note, contains('Saran AI tidak dapat dipakai'));

      final offTotal = _recommendation();
      (offTotal['stages'] as List<Map<String, dynamic>>).last['water_cum_g'] =
          239.5;
      expect(
        AiBrew.recommendationFromResponse(
          fallback: defaultPlan,
          requestedPouringCount: 3,
          response: offTotal,
        ).usedFallback,
        isTrue,
      );
    },
  );

  test('jumlah tahap dibandingkan permintaan, bukan rencana fallback', () {
    final oneStage = {
      ..._recommendation(),
      'stages': [
        {'name': 'bloom', 'start_s': 0, 'duration_s': 40, 'water_cum_g': 240},
      ],
    };
    final accepted = AiBrew.recommendationFromResponse(
      fallback: defaultPlan,
      requestedPouringCount: 1,
      response: oneStage,
    );
    expect(accepted.usedFallback, isFalse);
    expect(accepted.plan.pouringCount, 1);
    final rejected = AiBrew.recommendationFromResponse(
      fallback: defaultPlan,
      requestedPouringCount: 3,
      response: oneStage,
    );
    expect(rejected.usedFallback, isTrue);
  });

  test('payload diagnosis mengirim target dan aktual sebagai angka', () {
    final result = BrewSessionResult(
      plan: defaultPlan,
      totalTimeS: 100,
      drawdownS: 12,
      brewedAtUtc: '2026-10-21T00:00:00Z',
    );
    final payload = AiBrew.diagnosePayload(
      bean: _bean(),
      result: result,
      tasteScore: 3,
      tasteTags: [RoasteryNoteTag.asam],
      actualWaterG: [42, 95, 100],
      history: [],
      notes: 'catatan',
    );
    final brew = payload['brew'] as Map<String, Object?>;
    final stages = brew['stages'] as List<Map<String, Object?>>;
    expect(brew['taste_tags'], 'asam');
    expect(stages.first['target_water_cum_g'], 45);
    expect(stages.first['actual_water_g'], 42);
    expect(stages.last['drawdown_s'], 12);
    expect(stages.last['target_water_cum_g'], 240);
    expect(stages.last['target_water_cum_g'], isA<num>());
  });

  test('riwayat recommend dibatasi lima dan berisi seduhan aktif', () {
    final payload = AiBrew.recommendPayload(
      bean: _bean(),
      history: List.generate(6, _history),
      pouringCount: 3,
    );
    final history = payload['history'] as List<Map<String, Object?>>;
    expect(history, hasLength(5));
    expect(history.first['taste_tags'], 'asam');
    expect(history.first['notes'], 'Riwayat');
    expect((payload['bean'] as Map)['species'], 'arabika');
  });

  test('fallback diagnosis aman dan bisa diterapkan ke seduhan berikutnya', () {
    final customPlan = BrewCalculator.updateDuration(
      defaultPlan,
      stageIndex: 1,
      durationSeconds: 45,
    );
    final advice = AiBrew.fallbackDiagnosis(
      plan: customPlan,
      tasteScore: 3,
      tasteTags: ['asam'],
    );
    expect(AiBrew.validDiagnosis(advice), isTrue);
    expect(AiBrew.diagnosisSummary(advice), contains('Saran cadangan'));
    final next = AiBrew.planFromDiagnosis(base: customPlan, diagnosis: advice);
    expect(next?.waterTempC, 93);
    expect(
      next?.stages[1].durationSeconds,
      BrewCalculator.defaultPourDurationSeconds,
    );
    expect(() => BrewCalculator.validatePlan(next!), returnsNormally);
  });

  test('diagnosis dengan variabel asing ditolak', () {
    final invalid = {
      'diagnosis': 'Perlu perubahan.',
      'likely_causes': ['Mungkin suhu.'],
      'suggestions': [
        {'variable': 'pressure', 'from': 1, 'to': 2, 'reason': 'Coba.'},
      ],
      'note': 'Catat hasil.',
    };
    expect(AiBrew.validDiagnosis(invalid), isFalse);
    expect(
      AiBrew.planFromDiagnosis(base: defaultPlan, diagnosis: invalid),
      isNull,
    );
  });
}

Map<String, dynamic> _recommendation() => {
  'dose_g': 15,
  'ratio': 16,
  'water_temp_c': 92,
  'grind': 'sedang',
  'stages': <Map<String, dynamic>>[
    {'name': 'bloom', 'start_s': 0, 'duration_s': 40, 'water_cum_g': 45},
    {'name': 'pouring_2', 'start_s': 40, 'duration_s': 30, 'water_cum_g': 143},
    {'name': 'pouring_3', 'start_s': 70, 'duration_s': 30, 'water_cum_g': 240},
  ],
  'note': 'Titik awal seduh.',
};

Bean _bean() => const Bean(
  id: 'bean-1',
  userId: 'user-1',
  name: 'Arabika Flores',
  species: BeanSpecies.arabika,
  isSelfRoasted: false,
  initialStockG: 250,
  remainingStockG: 200,
  roasteryNotesTags: [],
  archived: false,
  createdAt: '2026-10-21T00:00:00Z',
  updatedAt: '2026-10-21T00:00:00Z',
  syncStatus: 'synced',
  brewCount: 0,
);

BrewDetailData _history(int index) => BrewDetailData(
  item: BrewJournalItem(
    id: 'brew-$index',
    userId: 'user-1',
    seq: index + 1,
    beanId: 'bean-1',
    beanName: 'Arabika Flores',
    isBestBrew: index == 0,
    brewedAtUtc: '2026-10-21T00:00:00Z',
    doseG: 15,
    ratio: 16,
    waterTempC: 92,
    grind: Grind.sedang,
    totalTimeS: 100,
    tasteScore: 3,
    tasteTags: const ['asam'],
    status: 'aktif',
    syncStatus: 'synced',
    hash: 'hash',
  ),
  notes: 'Riwayat',
  prevHash: 'prev',
  createdAt: '2026-10-21T00:00:00Z',
  roasteryNotesTags: const [],
  isBeanArchived: false,
  stages: const [],
);
