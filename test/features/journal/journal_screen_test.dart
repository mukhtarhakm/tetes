import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/data/remote/ai_client.dart';
import 'package:tetes/data/repositories/bean_repo.dart';
import 'package:tetes/data/repositories/brew_repo.dart';
import 'package:tetes/features/auth/state/session_controller.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/beans/state/bean_providers.dart';
import 'package:tetes/features/brew/state/ai_client_provider.dart';
import 'package:tetes/features/brew/state/brew_setup_controller.dart';
import 'package:tetes/features/brew/brew_plan.dart';
import 'package:tetes/features/journal/journal_model.dart';
import 'package:tetes/features/journal/screens/brew_detail_screen.dart';
import 'package:tetes/features/journal/screens/journal_screen.dart';
import 'package:tetes/features/journal/state/journal_controller.dart';

void main() {
  BrewJournalItem testItem({
    String id = 'brew-1',
    String beanName = 'Gayo Arabica',
    bool isBestBrew = true,
    String status = 'aktif',
    String syncStatus = 'synced',
    int tasteScore = 4,
    double ratio = 15.5,
    int waterTempC = 93,
    double doseG = 15.0,
    int totalTimeS = 180,
    List<String> tasteTags = const ['asam', 'buah'],
  }) {
    return BrewJournalItem(
      id: id,
      userId: 'user-1',
      seq: 1,
      beanId: 'bean-1',
      beanName: beanName,
      beanRoastery: 'Roastery Kita',
      isBestBrew: isBestBrew,
      brewedAtUtc: '2026-10-18T10:00:00Z',
      doseG: doseG,
      ratio: ratio,
      waterTempC: waterTempC,
      grind: Grind.sedang,
      totalTimeS: totalTimeS,
      tasteScore: tasteScore,
      tasteTags: tasteTags,
      costIdr: 4500,
      status: status,
      syncStatus: syncStatus,
      hash: 'abcdef1234567890abcdef1234567890',
    );
  }

  BrewDetailData testDetail({
    bool isBeanArchived = false,
    String status = 'aktif',
    String? aiAdvice,
  }) {
    final item = testItem(status: status);
    return BrewDetailData(
      item: item,
      notes: 'Seduhan enak dan seimbang',
      aiAdvice: aiAdvice ?? 'Saran coba turunkan suhu 1 derajat',
      prevHash: '0',
      createdAt: '2026-10-18T10:00:00Z',
      roasteryNotesTags: const ['floral', 'buah'],
      roasteryNotesText: 'Aroma bunga sedap',
      isBeanArchived: isBeanArchived,
      stages: const [
        BrewDetailStage(
          id: 'stage-1',
          brewId: 'brew-1',
          position: 1,
          name: BrewStageName.bloom,
          targetStartS: 0,
          targetDurationS: 40,
          targetWaterCumG: 45,
          targetPourG: 45,
          actualWaterG: 45,
          drawdownS: null,
        ),
        BrewDetailStage(
          id: 'stage-2',
          brewId: 'brew-1',
          position: 2,
          name: BrewStageName.pouring2,
          targetStartS: 40,
          targetDurationS: 80,
          targetWaterCumG: 232.5,
          targetPourG: 187.5,
          actualWaterG: 187,
          drawdownS: 35,
        ),
      ],
    );
  }

  testWidgets(
    'JournalScreen menampilkan keadaan kosong jika belum ada seduhan',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalBrewsProvider.overrideWith((ref) => Future.value(const [])),
          ],
          child: const MaterialApp(home: JournalScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada seduhan'), findsOneWidget);
      expect(find.text('Mulai seduh'), findsOneWidget);
    },
  );

  testWidgets(
    'JournalScreen menampilkan keadaan filter kosong dengan tombol reset',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalBrewsProvider.overrideWith((ref) => Future.value(const [])),
            journalFilterProvider.overrideWith(
              () => _MockFilterNotifier(
                const JournalFilter(searchQuery: 'tidak-ada'),
              ),
            ),
          ],
          child: const MaterialApp(home: JournalScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada seduhan yang cocok'), findsOneWidget);
      expect(find.text('Reset filter'), findsWidgets);
    },
  );

  testWidgets(
    'JournalScreen menampilkan kartu seduhan dengan informasi lengkap',
    (tester) async {
      final item = testItem();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalBrewsProvider.overrideWith((ref) => Future.value([item])),
          ],
          child: const MaterialApp(home: JournalScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Gayo Arabica'), findsOneWidget);
      expect(find.text('Roastery Kita'), findsOneWidget);
      expect(find.text('1:15.5'), findsOneWidget);
      expect(find.text('93°C'), findsOneWidget);
      expect(find.text('4/5'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('Terbaik'), findsOneWidget);
      expect(find.text('Tersinkron'), findsOneWidget);
      expect(find.text('asam'), findsOneWidget);
      expect(find.text('buah'), findsOneWidget);
      expect(find.text('1 seduhan'), findsOneWidget);
    },
  );

  testWidgets(
    'BrewDetailScreen menampilkan ringkasan, tabel tahap, dan konfirmasi pembatalan',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final detail = testDetail();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brewDetailProvider(
              'brew-1',
            ).overrideWith((ref) => Future.value(detail)),
          ],
          child: const MaterialApp(home: BrewDetailScreen(brewId: 'brew-1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ringkasan Parameter'), findsOneWidget);
      expect(find.text('Tabel Tahap Seduh'), findsOneWidget);
      expect(find.text('Rasa & Catatan Roastery'), findsOneWidget);
      expect(find.text('Seduhan enak dan seimbang'), findsOneWidget);
      expect(find.text('Diagnosa AI'), findsOneWidget);
      expect(find.text('Hash (8 karakter pertama)'), findsOneWidget);
      expect(find.text('abcdef12...'), findsOneWidget);
      expect(find.text('Seduh lagi dengan pengaturan ini'), findsOneWidget);
      expect(find.text('Tandai dibatalkan'), findsOneWidget);

      // Ketuk tombol tandai dibatalkan
      await tester.tap(find.text('Tandai dibatalkan'));
      await tester.pumpAndSettle();

      // Dialog konfirmasi harus muncul
      expect(find.text('Tandai dibatalkan?'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
    },
  );

  testWidgets(
    'Seduh lagi dengan biji terarsip menampilkan pesan jelas dan tidak lanjut',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final detail = testDetail(isBeanArchived: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brewDetailProvider(
              'brew-1',
            ).overrideWith((ref) => Future.value(detail)),
          ],
          child: const MaterialApp(home: BrewDetailScreen(brewId: 'brew-1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Seduh lagi dengan pengaturan ini'));
      await tester.pump();

      expect(
        find.text(
          'Biji kopi ini sudah diarsipkan dan tidak dapat diseduh lagi.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Saran AI JSON ditampilkan sebagai isi diagnosa', (tester) async {
    final advice = jsonEncode({
      'diagnosis': 'Ekstraksi kurang merata.',
      'likely_causes': ['Air kurang panas.'],
      'suggestions': [
        {
          'variable': 'water_temp_c',
          'from': 93,
          'to': 94,
          'reason': 'Coba naikkan suhu satu derajat.',
        },
      ],
      'note': 'Uji satu perubahan dulu.',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          brewDetailProvider(
            'brew-1',
          ).overrideWith((ref) => Future.value(testDetail(aiAdvice: advice))),
        ],
        child: const MaterialApp(home: BrewDetailScreen(brewId: 'brew-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.textContaining('Ekstraksi kurang merata.'),
      400,
    );
    expect(find.textContaining('Ekstraksi kurang merata.'), findsOneWidget);
    expect(find.textContaining('Suhu air: 93 → 94'), findsOneWidget);
    expect(find.textContaining('"likely_causes"'), findsNothing);
  });

  testWidgets(
    'galat diagnosa menampilkan fallback tanpa menyimpan dan memulai cooldown',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _AdviceBrewRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brewDetailProvider(
              'brew-1',
            ).overrideWith((ref) async => testDetail(aiAdvice: '')),
            sessionControllerProvider.overrideWith(
              _AdviceSessionController.new,
            ),
            beanRepositoryProvider.overrideWith(
              (ref) async => _AdviceBeanRepository(),
            ),
            brewRepositoryProvider.overrideWith((ref) async => repo),
            aiClientProvider.overrideWith((ref) => _FailingAiClient()),
          ],
          child: const MaterialApp(home: BrewDetailScreen(brewId: 'brew-1')),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Minta Diagnosa AI'), 400);
      await tester.tap(find.text('Minta Diagnosa AI'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Saran sederhana'), findsOneWidget);
      expect(find.textContaining('Coba lagi dalam 30 detik'), findsOneWidget);
      expect(repo.updates, 0);
    },
  );

  testWidgets('respons setelah Detail ditutup tidak menyimpan saran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _AdviceBrewRepository();
    final response = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          brewDetailProvider(
            'brew-1',
          ).overrideWith((ref) async => testDetail(aiAdvice: '')),
          sessionControllerProvider.overrideWith(_AdviceSessionController.new),
          beanRepositoryProvider.overrideWith(
            (ref) async => _AdviceBeanRepository(),
          ),
          brewRepositoryProvider.overrideWith((ref) async => repo),
          aiClientProvider.overrideWith(
            (ref) => _ControlledAiClient(response.future),
          ),
        ],
        child: const MaterialApp(home: BrewDetailScreen(brewId: 'brew-1')),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Minta Diagnosa AI'), 400);
    await tester.tap(find.text('Minta Diagnosa AI'));
    await tester.pump();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Layar lain'))),
    );
    response.complete({
      'diagnosis': 'Uji',
      'likely_causes': ['Uji'],
      'suggestions': [
        {'variable': 'water_temp_c', 'from': 93, 'to': 94, 'reason': 'Uji'},
      ],
      'note': 'Uji',
    });
    await tester.pump();
    expect(find.text('Layar lain'), findsOneWidget);
    expect(repo.updates, 0);
    expect(tester.takeException(), isNull);
  });
}

class _AdviceSessionController extends SessionController {
  @override
  Future<SessionState> build() async =>
      const SessionState.authenticated('user-1');
}

class _AdviceBeanRepository extends Fake implements BeanRepository {
  @override
  Future<Bean?> findById({required String userId, required String id}) async =>
      const Bean(
        id: 'bean-1',
        userId: 'user-1',
        name: 'Gayo Arabica',
        species: BeanSpecies.arabika,
        isSelfRoasted: false,
        initialStockG: 250,
        remainingStockG: 250,
        roasteryNotesTags: [],
        archived: false,
        createdAt: '2026-10-18T10:00:00Z',
        updatedAt: '2026-10-18T10:00:00Z',
        syncStatus: 'synced',
        brewCount: 1,
      );
}

class _AdviceBrewRepository extends Fake implements BrewRepository {
  int updates = 0;
  @override
  Future<List<BrewDetailData>> findAiHistory({
    required String userId,
    required String beanId,
  }) async => [];
  @override
  Future<int> updateAiAdvice({
    required String userId,
    required String brewId,
    required String aiAdvice,
  }) async {
    updates++;
    return 1;
  }
}

class _FailingAiClient extends Fake implements AiClient {
  @override
  Future<Map<String, dynamic>> diagnose({
    required String userId,
    required Map<String, Object?> payload,
  }) async => throw const AiException(
    AiFailure.upstream,
    'Layanan AI sedang bermasalah.',
    upstreamStatus: 503,
  );
}

class _ControlledAiClient extends Fake implements AiClient {
  _ControlledAiClient(this.response);
  final Future<Map<String, dynamic>> response;
  @override
  Future<Map<String, dynamic>> diagnose({
    required String userId,
    required Map<String, Object?> payload,
  }) => response;
}

class _MockFilterNotifier extends JournalFilterNotifier {
  _MockFilterNotifier(this._initial);
  final JournalFilter _initial;

  @override
  JournalFilter build() => _initial;
}
