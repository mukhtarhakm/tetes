import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/app_database.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/repositories/event_repo.dart';
import 'package:tetes/features/explore/event_model.dart';

void main() {
  late Database database;
  late EventRepository repository;
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
    repository = EventRepository(database);
  });
  tearDown(() async => database.close());

  EventDraft draft(Set<int> reminders) => EventDraft(
    name: 'Pameran',
    eventType: 'pameran',
    startUtc: DateTime.utc(2026, 7, 1, 13),
    sourceZone: 'Europe/London',
    reminders: reminders,
  );

  test('pengingat wajib 1-3 dan tersimpan menurun', () {
    expect(() => draft({}).validate(), throwsArgumentError);
    expect(() => draft({1440, 180, 30, 5}).validate(), throwsArgumentError);
    expect(draft({30, 1440, 180}).reminderText, '1440,180,30');
  });

  test('CRUD terikat user, update pending, hapus lunak tersembunyi', () async {
    final id = await repository.create('user-1', draft({30, 1440}));
    await repository.create('user-2', draft({180}));
    expect((await repository.listActive('user-1')).length, 1);
    expect(await repository.findById('user-2', id), isNull);
    final original = (await database.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
    await database.update(
      'events',
      {'updated_at': '2000-01-01T00:00:00Z', 'sync_status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
    await repository.update('user-1', id, draft({30}));
    final updated = (await database.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
    expect(updated['updated_at'], isNot('2000-01-01T00:00:00Z'));
    expect(updated['sync_status'], 'pending');
    expect(updated['reminder_minutes'], '30');
    expect(original['start_utc'], '2026-07-01T13:00:00Z');
    expect(() => repository.softDelete('user-2', id), throwsStateError);
    await repository.softDelete('user-1', id);
    expect(await repository.listActive('user-1'), isEmpty);
    expect(await repository.findById('user-1', id), isNull);
    final deleted = (await database.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    )).single;
    expect(deleted['deleted'], 1);
    expect(deleted['sync_status'], 'pending');
  });
}
