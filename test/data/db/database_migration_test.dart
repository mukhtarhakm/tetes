import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/app_database.dart';
import 'package:tetes/data/db/database_migrations.dart';

void main() {
  late Database database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseMigrations.schemaVersion,
        onConfigure: AppDatabase.configureDatabase,
        onCreate: DatabaseMigrations.create,
        onUpgrade: DatabaseMigrations.migrate,
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('migrasi 1 membuat semua tabel, indeks, dan user_version', () async {
    final tableRows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    final tableNames = tableRows.map((row) => row['name']).toSet();

    expect(tableNames, {
      'beans',
      'brew_stages',
      'brews',
      'events',
      'feedback',
      'game_scores',
      'settings',
      'stores',
      'users',
    });

    final indexRows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    final indexNames = indexRows.map((row) => row['name']).toSet();
    expect(indexNames, {
      'idx_brews_bean',
      'idx_brews_user_seq',
      'idx_events_user_time',
      'idx_stages_brew',
    });

    final versionRows = await database.rawQuery('PRAGMA user_version');
    expect(
      versionRows.single['user_version'],
      DatabaseMigrations.schemaVersion,
    );

    final userColumns = await database.rawQuery('PRAGMA table_info(users)');
    expect(userColumns.map((column) => column['name']).toList(), [
      'id',
      'username',
      'photo_path',
      'created_at',
      'last_login_at',
    ]);
  });

  test('foreign key aktif dan menolak brew_stage tanpa brew', () async {
    final foreignKeyRows = await database.rawQuery('PRAGMA foreign_keys');
    expect(foreignKeyRows.single['foreign_keys'], 1);

    expect(
      () => database.insert('brew_stages', {
        'id': 'stage-1',
        'brew_id': 'brew-tidak-ada',
        'position': 1,
        'name': 'blooming',
        'target_start_s': 0,
        'target_duration_s': 30,
        'target_water_cum_g': 45.0,
        'target_pour_g': 45.0,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('unique user_id dan seq menolak urutan ganda', () async {
    await database.insert('beans', {
      'id': 'bean-1',
      'user_id': 'user-1',
      'name': 'Biji uji',
      'species': 'arabika',
      'created_at': '2026-10-18T00:00:00Z',
      'updated_at': '2026-10-18T00:00:00Z',
    });

    await database.insert('brews', _brew(id: 'brew-1'));

    expect(
      () => database.insert('brews', _brew(id: 'brew-2')),
      throwsA(isA<DatabaseException>()),
    );
  });
}

Map<String, Object> _brew({required String id}) {
  return {
    'id': id,
    'user_id': 'user-1',
    'seq': 1,
    'bean_id': 'bean-1',
    'brewed_at_utc': '2026-10-18T00:00:00Z',
    'dose_g': 15.0,
    'ratio': 16.0,
    'water_temp_c': 92,
    'grind': 'sedang',
    'total_time_s': 180,
    'taste_score': 4,
    'taste_tags': 'manis',
    'prev_hash': '0',
    'hash': 'hash-uji',
    'created_at': '2026-10-18T00:00:00Z',
  };
}
