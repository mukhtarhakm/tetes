import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/app_database.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/repositories/bean_repo.dart';
import 'package:tetes/data/repositories/brew_repo.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/brew/brew_plan.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/brew_session_result.dart';
import 'package:tetes/core/utils/hash.dart';

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

  test('membaca pengaturan terbaik yang valid beserta tahapnya', () async {
    final beanId = await _createBean(beanRepository);
    await database.insert('brews', _brew(beanId: beanId));
    await database.insert(
      'brew_stages',
      _stage(
        id: 'stage-1',
        position: 1,
        name: 'bloom',
        start: 0,
        duration: 40,
        cumulative: 45,
        pour: 45,
      ),
    );
    await database.insert(
      'brew_stages',
      _stage(
        id: 'stage-2',
        position: 2,
        name: 'pouring_2',
        start: 40,
        duration: 35,
        cumulative: 145,
        pour: 100,
      ),
    );
    await database.insert(
      'brew_stages',
      _stage(
        id: 'stage-3',
        position: 3,
        name: 'pouring_3',
        start: 75,
        duration: 30,
        cumulative: 240,
        pour: 95,
      ),
    );
    await database.update(
      'beans',
      {'best_brew_id': 'brew-best'},
      where: 'id = ?',
      whereArgs: [beanId],
    );

    final bean = await beanRepository.findById(userId: 'user-1', id: beanId);
    final plan = await brewRepository.findBestPlan(
      userId: 'user-1',
      beanId: beanId,
      bestBrewId: bean!.bestBrewId!,
    );

    expect(plan, isNotNull);
    expect(plan!.fromBestBrew, isTrue);
    expect(plan.grind, Grind.sedangHalus);
    expect(plan.stages.map((stage) => stage.startSeconds), [0, 40, 75]);
    expect(plan.stages.map((stage) => stage.targetPourG), [45, 100, 95]);
    expect(plan.cumulativeWaterAt(2), 240);
  });

  test('best_brew_id yang tidak valid menghasilkan fallback null', () async {
    final beanId = await _createBean(beanRepository);

    final plan = await brewRepository.findBestPlan(
      userId: 'user-1',
      beanId: beanId,
      bestBrewId: 'tidak-ada',
    );

    expect(plan, isNull);
  });

  test('tahap yang tumpang tindih dianggap tidak valid', () async {
    final beanId = await _createBean(beanRepository);
    await database.insert('brews', _brew(beanId: beanId));
    await database.insert(
      'brew_stages',
      _stage(
        id: 'stage-1',
        position: 1,
        name: 'bloom',
        start: 0,
        duration: 40,
        cumulative: 45,
        pour: 45,
      ),
    );
    await database.insert(
      'brew_stages',
      _stage(
        id: 'stage-2',
        position: 2,
        name: 'pouring_2',
        start: 35,
        duration: 30,
        cumulative: 240,
        pour: 195,
      ),
    );

    final plan = await brewRepository.findBestPlan(
      userId: 'user-1',
      beanId: beanId,
      bestBrewId: 'brew-best',
    );

    expect(plan, isNull);
  });

  test('tahap yang memiliki celah dianggap tidak valid', () async {
    final beanId = await _createBean(beanRepository);
    await database.insert('brews', _brew(beanId: beanId));
    await database.insert(
      'brew_stages',
      _stage(
        id: 'stage-1',
        position: 1,
        name: 'bloom',
        start: 0,
        duration: 40,
        cumulative: 45,
        pour: 45,
      ),
    );
    await database.insert(
      'brew_stages',
      _stage(
        id: 'stage-2',
        position: 2,
        name: 'pouring_2',
        start: 45,
        duration: 30,
        cumulative: 240,
        pour: 195,
      ),
    );

    final plan = await brewRepository.findBestPlan(
      userId: 'user-1',
      beanId: beanId,
      bestBrewId: 'brew-best',
    );

    expect(plan, isNull);
  });

  test(
    'simpan dua seduhan membentuk rantai, tahap, biaya, dan pengaturan terbaik',
    () async {
      final beanId = await _createBean(beanRepository);
      await database.update(
        'beans',
        {'price_idr_per_kg': 200000},
        where: 'id = ?',
        whereArgs: [beanId],
      );
      final plan = BrewCalculator.createDefault(beanId: beanId);
      final result = BrewSessionResult(
        plan: plan,
        totalTimeS: 135,
        drawdownS: 35,
        brewedAtUtc: '2026-10-20T01:02:03Z',
      );
      final firstId = await brewRepository.save(
        userId: 'user-1',
        result: result,
        tasteScore: 4,
        tasteTags: [RoasteryNoteTag.manis],
        actualWaterG: List.filled(plan.stages.length, null),
        drawdownS: 35,
        aiAdvice: '{"diagnosis":"Seduhan seimbang."}',
      );
      final secondId = await brewRepository.save(
        userId: 'user-1',
        result: result,
        tasteScore: 4,
        tasteTags: [RoasteryNoteTag.cokelat, RoasteryNoteTag.manis],
        actualWaterG: List.filled(plan.stages.length, null),
      );
      final brews = await database.query('brews', orderBy: 'seq ASC');
      expect(brews.map((row) => row['seq']), [1, 2]);
      expect(brews.first['prev_hash'], '0');
      expect(brews.last['prev_hash'], brews.first['hash']);
      expect(brews.first['brewed_at_utc'], result.brewedAtUtc);
      expect(brews.first['ai_advice'], '{"diagnosis":"Seduhan seimbang."}');
      expect(brews.first['cost_idr'], brewCost(plan.doseG, 200000));
      expect(brews.last['taste_tags'], 'cokelat,manis');
      expect(await brewRepository.verifyUserChain('user-1'), 'utuh (2 entri)');
      expect(
        (await beanRepository.findById(
          userId: 'user-1',
          id: beanId,
        ))!.bestBrewId,
        secondId,
      );
      expect(
        await brewRepository.remainingStockG(userId: 'user-1', beanId: beanId),
        250 - plan.doseG * 2,
      );
      final stages = await database.query(
        'brew_stages',
        where: 'brew_id = ?',
        whereArgs: [firstId],
        orderBy: 'position',
      );
      expect(
        stages.every(
          (row) =>
              row['actual_start_s'] == null && row['actual_duration_s'] == null,
        ),
        isTrue,
      );
      expect(stages.last['drawdown_s'], 35);
      expect(
        stages
            .take(stages.length - 1)
            .every((row) => row['drawdown_s'] == null),
        isTrue,
      );
      expect(
        hashEntry((
          beanId: beanId,
          doseG: plan.doseG,
          ratio: plan.ratio,
          waterTempC: plan.waterTempC,
          grind: plan.grind.databaseValue,
          totalTimeS: 135,
          tasteScore: 4,
          tasteTags: ['manis'],
          brewedAtUtc: result.brewedAtUtc,
        ), '0'),
        brews.first['hash'],
      );
    },
  );

  test(
    'riwayat AI hanya best dan empat seduhan aktif terbaru milik user',
    () async {
      final beanId = await _createBean(beanRepository);
      final plan = BrewCalculator.createDefault(beanId: beanId);
      final result = BrewSessionResult(
        plan: plan,
        totalTimeS: 120,
        drawdownS: null,
        brewedAtUtc: '2026-10-20T01:02:03Z',
      );
      final ids = <String>[];
      for (var index = 0; index < 8; index++) {
        ids.add(
          await brewRepository.save(
            userId: 'user-1',
            result: result,
            tasteScore: index == 0 ? 5 : 3,
            tasteTags: [RoasteryNoteTag.manis],
            actualWaterG: List.filled(plan.stages.length, null),
            notes: index == 0 ? 'Seduhan terbaik' : null,
          ),
        );
      }
      await brewRepository.cancelBrew(userId: 'user-1', brewId: ids[6]);

      final history = await brewRepository.findAiHistory(
        userId: 'user-1',
        beanId: beanId,
      );
      expect(history.map((detail) => detail.item.id), [
        ids[0],
        ids[7],
        ids[5],
        ids[4],
        ids[3],
      ]);
      expect(history.first.notes, 'Seduhan terbaik');
      expect(history.first.stages, hasLength(plan.stages.length));
      expect(
        await brewRepository.findAiHistory(userId: 'user-2', beanId: beanId),
        isEmpty,
      );
      expect(
        await brewRepository.findAiHistory(userId: 'user-1', beanId: 'other'),
        isEmpty,
      );
    },
  );

  test('gagal menyimpan tidak meninggalkan brews atau tahap', () async {
    final plan = BrewCalculator.createDefault(beanId: 'hilang');
    await expectLater(
      brewRepository.save(
        userId: 'user-1',
        result: BrewSessionResult(
          plan: plan,
          totalTimeS: 100,
          drawdownS: null,
          brewedAtUtc: '2026-10-20T01:02:03Z',
        ),
        tasteScore: 3,
        tasteTags: [RoasteryNoteTag.manis],
        actualWaterG: List.filled(plan.stages.length, null),
      ),
      throwsA(isA<BrewSaveException>()),
    );
    expect(await database.query('brews'), isEmpty);
    expect(await database.query('brew_stages'), isEmpty);
  });

  test(
    'entri dibatalkan tetap menjadi pendahulu dan stok hanya menghitung aktif',
    () async {
      final beanId = await _createBean(beanRepository);
      final plan = BrewCalculator.createDefault(beanId: beanId);
      final result = BrewSessionResult(
        plan: plan,
        totalTimeS: 100,
        drawdownS: null,
        brewedAtUtc: '2026-10-20T01:02:03Z',
      );
      final first = await brewRepository.save(
        userId: 'user-1',
        result: result,
        tasteScore: 3,
        tasteTags: [RoasteryNoteTag.manis],
        actualWaterG: List.filled(plan.stages.length, null),
      );
      await database.update(
        'brews',
        {'status': 'dibatalkan'},
        where: 'id = ?',
        whereArgs: [first],
      );
      await brewRepository.save(
        userId: 'user-1',
        result: result,
        tasteScore: 4,
        tasteTags: [RoasteryNoteTag.manis],
        actualWaterG: List.filled(plan.stages.length, null),
      );
      final rows = await database.query('brews', orderBy: 'seq');
      expect(rows.last['seq'], 2);
      expect(rows.last['prev_hash'], rows.first['hash']);
      expect(await brewRepository.verifyUserChain('user-1'), 'utuh (2 entri)');
      expect(
        await brewRepository.remainingStockG(userId: 'user-1', beanId: beanId),
        250 - plan.doseG,
      );
      expect(
        await brewRepository.isLowStock(userId: 'user-1', beanId: beanId),
        isFalse,
      );
      await database.insert('settings', {
        'user_id': 'user-1',
        'key': 'low_stock_threshold_g',
        'value': '240',
      });
      expect(
        await brewRepository.isLowStock(userId: 'user-1', beanId: beanId),
        isTrue,
      );
    },
  );

  test('biji terarsip ditolak tanpa data setengah jadi', () async {
    final beanId = await _createBean(beanRepository);
    await beanRepository.archive(userId: 'user-1', id: beanId);
    final plan = BrewCalculator.createDefault(beanId: beanId);
    await expectLater(
      brewRepository.save(
        userId: 'user-1',
        result: BrewSessionResult(
          plan: plan,
          totalTimeS: 100,
          drawdownS: null,
          brewedAtUtc: '2026-10-20T01:02:03Z',
        ),
        tasteScore: 3,
        tasteTags: [RoasteryNoteTag.manis],
        actualWaterG: List.filled(plan.stages.length, null),
      ),
      throwsA(isA<BrewSaveException>()),
    );
    expect(await database.query('brews'), isEmpty);
  });
}

Future<String> _createBean(BeanRepository repository) {
  return repository.create(
    userId: 'user-1',
    draft: const BeanDraft(
      name: 'Biji Uji',
      species: BeanSpecies.arabika,
      isSelfRoasted: false,
      initialStockG: 250,
      roasteryNotesTags: [],
    ),
  );
}

Map<String, Object> _brew({required String beanId}) {
  return {
    'id': 'brew-best',
    'user_id': 'user-1',
    'seq': 1,
    'bean_id': beanId,
    'brewed_at_utc': '2026-10-19T00:00:00Z',
    'dose_g': 15,
    'ratio': 16,
    'water_temp_c': 92,
    'grind': 'sedang_halus',
    'total_time_s': 119,
    'taste_score': 5,
    'taste_tags': 'manis',
    'status': 'aktif',
    'prev_hash': '0',
    'hash': 'hash-brew-best',
    'created_at': '2026-10-19T00:00:00Z',
  };
}

Map<String, Object> _stage({
  required String id,
  required int position,
  required String name,
  required int start,
  required int duration,
  required double cumulative,
  required double pour,
}) {
  return {
    'id': id,
    'brew_id': 'brew-best',
    'position': position,
    'name': name,
    'target_start_s': start,
    'target_duration_s': duration,
    'target_water_cum_g': cumulative,
    'target_pour_g': pour,
  };
}
