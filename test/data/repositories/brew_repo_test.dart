import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/app_database.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/repositories/bean_repo.dart';
import 'package:tetes/data/repositories/brew_repo.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/brew/brew_plan.dart';

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
        start: 47,
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
        start: 89,
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
    expect(plan.stages.map((stage) => stage.gapAfterSeconds), [7, 7, 0]);
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
