import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/remote/auth_client.dart';
import 'package:tetes/data/repositories/user_repo.dart';
import 'package:tetes/data/secure/session_storage.dart';

void main() {
  late Database database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseMigrations.create(database, DatabaseMigrations.schemaVersion);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'menghitung pending pada lima tabel hanya untuk pengguna aktif',
    () async {
      const userId = 'user-1';
      await database.insert('beans', {
        'id': 'bean-1',
        'user_id': userId,
        'name': 'Biji Uji',
        'species': 'arabika',
        'created_at': '2026-10-19T00:00:00Z',
        'updated_at': '2026-10-19T00:00:00Z',
      });
      await database.insert('brews', {
        'id': 'brew-1',
        'user_id': userId,
        'seq': 1,
        'bean_id': 'bean-1',
        'brewed_at_utc': '2026-10-19T00:00:00Z',
        'dose_g': 15,
        'ratio': 15,
        'water_temp_c': 92,
        'grind': 'medium',
        'total_time_s': 180,
        'taste_score': 4,
        'taste_tags': '[]',
        'prev_hash': '',
        'hash': 'hash-1',
        'created_at': '2026-10-19T00:00:00Z',
      });
      await database.insert('events', {
        'id': 'event-1',
        'user_id': userId,
        'name': 'Event Uji',
        'start_utc': '2026-10-20T00:00:00Z',
        'source_zone': 'WIB',
        'reminder_minutes': '[]',
        'created_at': '2026-10-19T00:00:00Z',
        'updated_at': '2026-10-19T00:00:00Z',
      });
      await database.insert('game_scores', {
        'id': 'score-1',
        'user_id': userId,
        'level': 1,
        'accuracy': 90,
        'stars': 3,
        'duration_s': 30,
        'played_at': '2026-10-19T00:00:00Z',
      });
      await database.insert('feedback', {
        'id': 'feedback-1',
        'user_id': userId,
        'suggestion': 'Saran',
        'created_at': '2026-10-19T00:00:00Z',
      });
      await database.insert('beans', {
        'id': 'bean-other',
        'user_id': 'user-2',
        'name': 'Biji Lain',
        'species': 'arabika',
        'created_at': '2026-10-19T00:00:00Z',
        'updated_at': '2026-10-19T00:00:00Z',
      });
      await database.insert('feedback', {
        'id': 'feedback-synced',
        'user_id': userId,
        'suggestion': 'Sudah terkirim',
        'created_at': '2026-10-19T00:00:00Z',
        'sync_status': 'synced',
      });
      final repository = UserRepository(
        database,
        AuthClient(client: MockClient((_) async => http.Response('', 500))),
        const _UnusedSessionStorage(),
      );

      final count = await repository.countPendingSyncData(userId);

      expect(count, 5);
    },
  );
}

class _UnusedSessionStorage implements SessionStorage {
  const _UnusedSessionStorage();

  @override
  Future<void> clearSession() async {}

  @override
  Future<List<String>> readPendingRevokeTokens() async => const [];

  @override
  Future<StoredSession?> readSession() async => null;

  @override
  Future<void> saveSession({
    required String token,
    required String userId,
    required String expiresAt,
  }) async {}

  @override
  Future<void> writePendingRevokeTokens(List<String> tokens) async {}
}
