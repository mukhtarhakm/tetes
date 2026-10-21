import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/repositories/feedback_repo.dart';

void main() {
  late Database database;
  late FeedbackRepository repository;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseMigrations.create(database, DatabaseMigrations.schemaVersion);
    repository = FeedbackRepository(database);
  });
  tearDown(() => database.close());

  test('validasi isi, batas panjang, dan satu kolom', () async {
    await expectLater(
      repository.save(userId: 'u1', suggestion: '  ', impression: ''),
      throwsArgumentError,
    );
    await expectLater(
      repository.save(userId: 'u1', suggestion: 'x' * 501, impression: ''),
      throwsArgumentError,
    );
    await repository.save(
      userId: 'u1',
      suggestion: '  Saran  ',
      impression: '',
    );
    final row = (await database.query('feedback')).single;
    expect(row['user_id'], 'u1');
    expect(row['suggestion'], 'Saran');
    expect(row['impression'], isNull);
    expect(row['sync_status'], 'pending');
    expect(
      row['created_at'],
      matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$')),
    );
    await repository.save(userId: 'u1', suggestion: '', impression: 'Kesan');
    expect((await database.query('feedback')).last['suggestion'], isNull);
  });

  test('riwayat terikat pengguna dan terbaru lebih dulu', () async {
    await repository.save(userId: 'u1', suggestion: 'awal', impression: '');
    await repository.save(userId: 'u2', suggestion: 'rahasia', impression: '');
    await repository.save(userId: 'u1', suggestion: 'akhir', impression: '');
    final rows = await repository.history('u1');
    expect(rows.map((row) => row['suggestion']), ['akhir', 'awal']);
    expect(rows.every((row) => row['suggestion'] != 'rahasia'), isTrue);
  });
}
