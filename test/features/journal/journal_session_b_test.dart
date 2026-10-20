import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/app/navigation/app_shell.dart';
import 'package:tetes/core/ui/score_chart.dart';
import 'package:tetes/data/db/app_database.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/repositories/bean_repo.dart';
import 'package:tetes/data/repositories/brew_repo.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/beans/state/bean_providers.dart';
import 'package:tetes/features/brew/brew_plan.dart';
import 'package:tetes/features/journal/journal_model.dart';
import 'package:tetes/features/journal/screens/brew_compare_screen.dart';
import 'package:tetes/features/journal/screens/journal_screen.dart';
import 'package:tetes/features/journal/state/journal_controller.dart';

void main() {
  late Database database;
  late BeanRepository beanRepository;
  late BrewRepository brewRepository;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseMigrations.schemaVersion,
        onConfigure: AppDatabase.configureDatabase,
        onCreate: DatabaseMigrations.create,
      ),
    );
    beanRepository = BeanRepository(database);
    brewRepository = BrewRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  BrewJournalItem makeItem({
    required String id,
    String beanId = 'bean-1',
    String beanName = 'Gayo Arabica',
    int seq = 1,
    String brewedAtUtc = '2026-10-18T10:00:00Z',
    double doseG = 15.0,
    double ratio = 15.0,
    int waterTempC = 92,
    Grind grind = Grind.sedang,
    int tasteScore = 4,
    String status = 'aktif',
  }) {
    return BrewJournalItem(
      id: id,
      userId: 'user-1',
      seq: seq,
      beanId: beanId,
      beanName: beanName,
      isBestBrew: false,
      brewedAtUtc: brewedAtUtc,
      doseG: doseG,
      ratio: ratio,
      waterTempC: waterTempC,
      grind: grind,
      totalTimeS: 180,
      tasteScore: tasteScore,
      tasteTags: const ['asam'],
      status: status,
      syncStatus: 'synced',
      hash: 'hash-$id',
    );
  }

  BrewDetailData makeDetail({
    required String id,
    String beanId = 'bean-1',
    String beanName = 'Gayo Arabica',
    int seq = 1,
    String brewedAtUtc = '2026-10-18T10:00:00Z',
    double doseG = 15.0,
    double ratio = 15.0,
    int waterTempC = 92,
    Grind grind = Grind.sedang,
    int tasteScore = 4,
    int? drawdownS,
  }) {
    return BrewDetailData(
      item: makeItem(
        id: id,
        beanId: beanId,
        beanName: beanName,
        seq: seq,
        brewedAtUtc: brewedAtUtc,
        doseG: doseG,
        ratio: ratio,
        waterTempC: waterTempC,
        grind: grind,
        tasteScore: tasteScore,
      ),
      prevHash: '0',
      createdAt: brewedAtUtc,
      roasteryNotesTags: const [],
      isBeanArchived: false,
      stages: [
        BrewDetailStage(
          id: 'stage-1',
          brewId: id,
          position: 1,
          name: BrewStageName.bloom,
          targetStartS: 0,
          targetDurationS: 40,
          targetWaterCumG: 45,
          targetPourG: 45,
          drawdownS: drawdownS,
        ),
      ],
    );
  }

  group('ScoreChart Widget', () {
    testWidgets('menampilkan pesan jika data kurang dari dua titik', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ScoreChart(scores: [4])),
        ),
      );
      expect(find.text('Belum cukup data untuk grafik'), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
    });

    testWidgets('menampilkan LineChart jika data minimal dua titik', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ScoreChart(scores: [3, 4, 5])),
        ),
      );
      expect(find.text('Belum cukup data untuk grafik'), findsNothing);
      expect(find.byType(LineChart), findsOneWidget);
    });
  });

  group('Selection Mode di Tab Jurnal', () {
    testWidgets('memilih maksimal 2 seduhan dan menolak pilihan ke-3 dengan pesan', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final items = [
        makeItem(id: 'b-1', seq: 1),
        makeItem(id: 'b-2', seq: 2),
        makeItem(id: 'b-3', seq: 3),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalBrewsProvider.overrideWith((ref) => Future.value(items)),
          ],
          child: const MaterialApp(home: JournalScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Aktifkan mode pilih
      await tester.tap(find.widgetWithText(TextButton, 'Bandingkan'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih 2 seduhan'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(3));

      // Pilih item 1
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      expect(find.text('Pilih 1 lagi'), findsOneWidget);

      // Pilih item 2
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      expect(find.text('2 dipilih'), findsOneWidget);

      // Coba pilih item 3 (harus ditolak)
      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pump();
      expect(
        find.text('Hanya dapat memilih tepat dua seduhan untuk dibandingkan.'),
        findsOneWidget,
      );
      expect(find.text('2 dipilih'), findsOneWidget);

      // Tombol Batal membersihkan pilihan dan keluar dari mode pilih
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(find.widgetWithText(TextButton, 'Bandingkan'), findsOneWidget);
    });

    testWidgets('Mode pilih keluar otomatis saat berpindah tab di AppShell', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final items = [
        makeItem(id: 'b-1', seq: 1),
        makeItem(id: 'b-2', seq: 2),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            journalBrewsProvider.overrideWith((ref) => Future.value(items)),
            beanListProvider.overrideWith(() => _MockBeanListNotifier(const [])),
          ],
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      // Buka tab Jurnal
      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();

      // Aktifkan mode pilih
      await tester.tap(find.widgetWithText(TextButton, 'Bandingkan'));
      await tester.pumpAndSettle();
      expect(find.text('Pilih 2 seduhan'), findsOneWidget);

      // Pindah ke tab Seduh
      await tester.tap(find.byIcon(Icons.coffee_rounded));
      await tester.pumpAndSettle();

      // Kembali ke tab Jurnal
      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();

      // Mode pilih harus sudah keluar otomatis dan bar aksi tidak ada
      expect(find.text('Pilih 2 seduhan'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Bandingkan'), findsOneWidget);
    });
  });

  group('BrewCompareScreen', () {
    testWidgets('menampilkan perbandingan 2 kolom dan menyoroti baris yang berbeda', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final older = makeDetail(
        id: 'brew-old',
        beanId: 'bean-A',
        beanName: 'Gayo Arabica',
        brewedAtUtc: '2026-10-18T10:00:00Z',
        waterTempC: 94,
        ratio: 16.0,
        tasteScore: 3,
      );
      final newer = makeDetail(
        id: 'brew-new',
        beanId: 'bean-B',
        beanName: 'Toraja Arabica',
        brewedAtUtc: '2026-10-19T10:00:00Z',
        waterTempC: 92,
        ratio: 15.0,
        tasteScore: 5,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            brewDetailProvider('brew-old').overrideWith((ref) => Future.value(older)),
            brewDetailProvider('brew-new').overrideWith((ref) => Future.value(newer)),
          ],
          child: const MaterialApp(
            home: BrewCompareScreen(brewId1: 'brew-new', brewId2: 'brew-old'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Periksa catatan Biji berbeda muncul
      expect(find.text('Biji berbeda'), findsOneWidget);

      // Periksa ringkasan perbandingan
      expect(find.text('Ringkasan Perbandingan'), findsOneWidget);
      expect(find.text('Biji berbeda. Skor naik 2 (dari 3 ke 5).'), findsOneWidget);

      // Periksa baris parameter berbeda disorot dengan badge "Beda"
      expect(find.text('Beda'), findsWidgets);

      // Nilai kosong di kedua sisi (misal drawdown null di kedua sisi) tidak disorot beda
      // Drawdown sama-sama null ('—')
      expect(find.text('Drawdown'), findsOneWidget);
    });
  });

  group('Sub-tab Biji & Database Query', () {
    test('listActive membaca best_brew aktif dan low_stock_threshold_g dari settings dalam satu query', (
      ) async {
      // Masukkan settings custom threshold 20g
      await database.insert('settings', {
        'user_id': 'user-1',
        'key': 'low_stock_threshold_g',
        'value': '20',
      });

      final beanId = await beanRepository.create(
        userId: 'user-1',
        draft: const BeanDraft(
          name: 'Biji Test',
          species: BeanSpecies.arabika,
          isSelfRoasted: false,
          initialStockG: 100,
          roasteryNotesTags: [],
        ),
      );

      // Seduhan 1 (aktif, skor 3)
      await database.insert('brews', {
        'id': 'br-1',
        'user_id': 'user-1',
        'seq': 1,
        'bean_id': beanId,
        'brewed_at_utc': '2026-10-18T10:00:00Z',
        'dose_g': 85.0, // tersisa 15g (di bawah threshold 20g)
        'ratio': 15.0,
        'water_temp_c': 90,
        'grind': 'sedang',
        'total_time_s': 180,
        'taste_score': 3,
        'taste_tags': 'manis',
        'status': 'aktif',
        'prev_hash': '0',
        'hash': 'h1',
        'created_at': '2026-10-18T10:00:00Z',
        'sync_status': 'synced',
      });

      // Seduhan 2 (aktif, skor 5) - best brew
      await database.insert('brews', {
        'id': 'br-2',
        'user_id': 'user-1',
        'seq': 2,
        'bean_id': beanId,
        'brewed_at_utc': '2026-10-19T10:00:00Z',
        'dose_g': 0.0,
        'ratio': 16.0,
        'water_temp_c': 92,
        'grind': 'sedang',
        'total_time_s': 180,
        'taste_score': 5,
        'taste_tags': 'buah',
        'status': 'aktif',
        'prev_hash': 'h1',
        'hash': 'h2',
        'created_at': '2026-10-19T10:00:00Z',
        'sync_status': 'synced',
      });

      await database.update('beans', {'best_brew_id': 'br-2'}, where: 'id = ?', whereArgs: [beanId]);

      final activeBeans = await beanRepository.listActive('user-1');
      expect(activeBeans.length, 1);
      final bean = activeBeans.first;

      // Ambang dibaca dari settings (20.0) sehingga sisa 15g adalah isLowStock = true
      expect(bean.lowStockThresholdG, 20.0);
      expect(bean.remainingStockG, 15.0);
      expect(bean.isLowStock, isTrue);

      // Best brew summary terbaca langsung tanpa N+1 query
      expect(bean.bestBrewTasteScore, 5);
      expect(bean.bestBrewWaterTempC, 92);
      expect(bean.bestBrewRatio, 16.0);
      expect(bean.bestBrewSummary, 'Terbaik: 1:16 • 92°C • ★ 5/5');

      // Jika best brew dibatalkan, tidak boleh tampil di summary
      await database.update('brews', {'status': 'dibatalkan'}, where: 'id = ?', whereArgs: ['br-2']);
      final afterCancelledBest = await beanRepository.listActive('user-1');
      expect(afterCancelledBest.first.bestBrewSummary, isNull);
    });

    test('findBrewsForBean hanya mengambil seduhan aktif untuk grafik (chronological)', (
      ) async {
      final beanId = await beanRepository.create(
        userId: 'user-1',
        draft: const BeanDraft(
          name: 'Biji Test 2',
          species: BeanSpecies.arabika,
          isSelfRoasted: false,
          initialStockG: 100,
          roasteryNotesTags: [],
        ),
      );

      // Seduhan lama (aktif)
      await database.insert('brews', {
        'id': 'b-old',
        'user_id': 'user-1',
        'seq': 1,
        'bean_id': beanId,
        'brewed_at_utc': '2026-10-18T10:00:00Z',
        'dose_g': 15.0,
        'ratio': 15.0,
        'water_temp_c': 90,
        'grind': 'sedang',
        'total_time_s': 180,
        'taste_score': 3,
        'taste_tags': 'manis',
        'status': 'aktif',
        'prev_hash': '0',
        'hash': 'h1',
        'created_at': '2026-10-18T10:00:00Z',
        'sync_status': 'synced',
      });

      // Seduhan tengah (dibatalkan)
      await database.insert('brews', {
        'id': 'b-mid',
        'user_id': 'user-1',
        'seq': 2,
        'bean_id': beanId,
        'brewed_at_utc': '2026-10-19T10:00:00Z',
        'dose_g': 15.0,
        'ratio': 15.0,
        'water_temp_c': 90,
        'grind': 'sedang',
        'total_time_s': 180,
        'taste_score': 1,
        'taste_tags': 'pahit',
        'status': 'dibatalkan',
        'prev_hash': 'h1',
        'hash': 'h2',
        'created_at': '2026-10-19T10:00:00Z',
        'sync_status': 'synced',
      });

      // Seduhan baru (aktif)
      await database.insert('brews', {
        'id': 'b-new',
        'user_id': 'user-1',
        'seq': 3,
        'bean_id': beanId,
        'brewed_at_utc': '2026-10-20T10:00:00Z',
        'dose_g': 15.0,
        'ratio': 15.0,
        'water_temp_c': 90,
        'grind': 'sedang',
        'total_time_s': 180,
        'taste_score': 5,
        'taste_tags': 'buah',
        'status': 'aktif',
        'prev_hash': 'h2',
        'hash': 'h3',
        'created_at': '2026-10-20T10:00:00Z',
        'sync_status': 'synced',
      });

      final activeBrews = await brewRepository.findBrewsForBean(
        userId: 'user-1',
        beanId: beanId,
        activeOnly: true,
        chronological: true,
      );

      // Seduhan dibatalkan tidak masuk
      expect(activeBrews.length, 2);
      expect(activeBrews.map((b) => b.id).toList(), ['b-old', 'b-new']);
      expect(activeBrews.map((b) => b.tasteScore).toList(), [3, 5]);
    });
  });
}

class _MockBeanListNotifier extends BeanListController {
  _MockBeanListNotifier(this._initial);
  final List<Bean> _initial;

  @override
  Future<List<Bean>> build() async => _initial;
}
