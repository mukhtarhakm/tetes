import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/repositories/chat_repo.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('pesan, status, dan hapus percakapan terisolasi per pengguna', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseMigrations.schemaVersion,
        onCreate: DatabaseMigrations.create,
        onUpgrade: DatabaseMigrations.migrate,
      ),
    );
    try {
      final repo = ChatRepository(database);
      final first = await repo.add(
        userId: 'user-1',
        role: 'user',
        content: 'Halo',
      );
      await repo.add(userId: 'user-2', role: 'user', content: 'Rahasia');
      await repo.markFailed(userId: 'user-2', id: first.id);
      expect((await repo.list('user-1')).single.failed, isFalse);
      await repo.markFailed(userId: 'user-1', id: first.id);
      expect((await repo.list('user-1')).single.failed, isTrue);
      expect((await repo.list('user-2')).single.content, 'Rahasia');
      await repo.deleteAll('user-1');
      expect(await repo.list('user-1'), isEmpty);
      expect((await repo.list('user-2')).single.content, 'Rahasia');
    } finally {
      await database.close();
    }
  });

  test('hitung kuota lokal mengikuti batas tanggal Asia/Jakarta', () async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseMigrations.schemaVersion,
        onCreate: DatabaseMigrations.create,
        onUpgrade: DatabaseMigrations.migrate,
      ),
    );
    try {
      final repo = ChatRepository(database);
      await database.insert('chat_messages', {
        'id': 'old',
        'user_id': 'u',
        'role': 'user',
        'content': 'Kemarin',
        'created_at': '2026-10-22T16:59:59Z',
        'status': 'sent',
      });
      await database.insert('chat_messages', {
        'id': 'new',
        'user_id': 'u',
        'role': 'user',
        'content': 'Hari ini',
        'created_at': '2026-10-22T17:00:00Z',
        'status': 'failed',
      });
      expect(await repo.countUserToday('u', DateTime.utc(2026, 10, 22, 17)), 1);
    } finally {
      await database.close();
    }
  });
}
