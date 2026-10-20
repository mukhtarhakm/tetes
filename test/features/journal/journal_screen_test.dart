import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  }) {
    final item = testItem(status: status);
    return BrewDetailData(
      item: item,
      notes: 'Seduhan enak dan seimbang',
      aiAdvice: 'Saran coba turunkan suhu 1 derajat',
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

  testWidgets('JournalScreen menampilkan keadaan kosong jika belum ada seduhan', (
    tester,
  ) async {
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
  });

  testWidgets('JournalScreen menampilkan keadaan filter kosong dengan tombol reset', (
    tester,
  ) async {
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
  });

  testWidgets('JournalScreen menampilkan kartu seduhan dengan informasi lengkap', (
    tester,
  ) async {
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
    expect(find.text('★ 4/5'), findsOneWidget);
    expect(find.text('Terbaik'), findsOneWidget);
    expect(find.text('Tersinkron'), findsOneWidget);
    expect(find.text('asam'), findsOneWidget);
    expect(find.text('buah'), findsOneWidget);
    expect(find.text('1 seduhan'), findsOneWidget);
  });

  testWidgets('BrewDetailScreen menampilkan ringkasan, tabel tahap, dan konfirmasi pembatalan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final detail = testDetail();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          brewDetailProvider('brew-1').overrideWith(
            (ref) => Future.value(detail),
          ),
        ],
        child: const MaterialApp(home: BrewDetailScreen(brewId: 'brew-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ringkasan Parameter'), findsOneWidget);
    expect(find.text('Tabel Tahap Seduh'), findsOneWidget);
    expect(find.text('Rasa & Catatan Roastery'), findsOneWidget);
    expect(find.text('Seduhan enak dan seimbang'), findsOneWidget);
    expect(find.text('Saran AI'), findsOneWidget);
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
  });

  testWidgets('Seduh lagi dengan biji terarsip menampilkan pesan jelas dan tidak lanjut', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final detail = testDetail(isBeanArchived: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          brewDetailProvider('brew-1').overrideWith(
            (ref) => Future.value(detail),
          ),
        ],
        child: const MaterialApp(home: BrewDetailScreen(brewId: 'brew-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Seduh lagi dengan pengaturan ini'));
    await tester.pump();

    expect(
      find.text('Biji kopi ini sudah diarsipkan dan tidak dapat diseduh lagi.'),
      findsOneWidget,
    );
  });
}

class _MockFilterNotifier extends JournalFilterNotifier {
  _MockFilterNotifier(this._initial);
  final JournalFilter _initial;

  @override
  JournalFilter build() => _initial;
}
