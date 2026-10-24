import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
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

  test(
    'instalasi baru membuat semua tabel, indeks, dan user_version 4',
    () async {
      final tableRows = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%' ORDER BY name",
      );
      final tableNames = tableRows.map((row) => row['name']).toSet();

      expect(tableNames, {
        'beans',
        'chat_messages',
        'chain_anchors',
        'chain_anchor_cooldowns',
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
        'idx_chat_messages_user_time',
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

      final beanColumns = await database.rawQuery('PRAGMA table_info(beans)');
      expect(
        beanColumns.map((column) => column['name']),
        contains('pack_size_g'),
      );
      expect(
        beanColumns.map((column) => column['name']),
        contains('process_custom'),
      );
    },
  );

  test('upgrade v2 ke v4 menjaga data lama', () async {
    final directory = await Directory.systemTemp.createTemp('tetes-migration-');
    final databasePath = path.join(directory.path, 'upgrade.db');
    Database? versionTwo;
    Database? upgraded;

    try {
      versionTwo = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onConfigure: AppDatabase.configureDatabase,
          onCreate: DatabaseMigrations.create,
          onUpgrade: DatabaseMigrations.migrate,
        ),
      );
      await versionTwo.insert('users', {
        'id': 'user-1',
        'username': 'lama',
        'created_at': '2026-10-18T00:00:00Z',
      });
      expect(await _userVersion(versionTwo), 2);
      await versionTwo.close();
      versionTwo = null;

      upgraded = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.schemaVersion,
          onConfigure: AppDatabase.configureDatabase,
          onCreate: DatabaseMigrations.create,
          onUpgrade: DatabaseMigrations.migrate,
        ),
      );

      expect(await _userVersion(database), 4);
      expect(await _userVersion(upgraded), 4);
      expect(await _beanSchema(upgraded), await _beanSchema(database));
      expect((await upgraded.query('users')).single['username'], 'lama');
      expect(await upgraded.query('chat_messages'), isEmpty);
    } finally {
      await versionTwo?.close();
      await upgraded?.close();
      await directory.delete(recursive: true);
    }
  });

  test('upgrade v3 ke v4 menjaga pengguna dan chat', () async {
    final directory = await Directory.systemTemp.createTemp('tetes-anchor-upgrade-');
    final databasePath = path.join(directory.path, 'upgrade.db');
    Database? old;
    Database? upgraded;
    try {
      old = await databaseFactoryFfi.openDatabase(databasePath,
        options: OpenDatabaseOptions(version: 3,
          onCreate: DatabaseMigrations.create,
          onUpgrade: DatabaseMigrations.migrate));
      await old.insert('users', {'id': 'user-1', 'username': 'lama',
        'created_at': '2026-10-24T00:00:00Z'});
      await old.insert('chat_messages', {'id': 'chat-1', 'user_id': 'user-1',
        'role': 'user', 'content': 'test', 'created_at': '2026-10-24T00:00:00Z',
        'status': 'sent'});
      await old.close();
      old = null;
      upgraded = await databaseFactoryFfi.openDatabase(databasePath,
        options: OpenDatabaseOptions(version: 4,
          onUpgrade: DatabaseMigrations.migrate));
      expect((await upgraded.query('users')).single['username'], 'lama');
      expect((await upgraded.query('chat_messages')).single['content'], 'test');
      expect(await upgraded.query('chain_anchors'), isEmpty);
    } finally {
      await old?.close();
      await upgraded?.close();
      await directory.delete(recursive: true);
    }
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

Future<int> _userVersion(Database database) async {
  final rows = await database.rawQuery('PRAGMA user_version');
  return rows.single['user_version']! as int;
}

Future<List<Map<String, Object?>>> _beanSchema(Database database) {
  return database.rawQuery('PRAGMA table_info(beans)');
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
