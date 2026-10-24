import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/repositories/chain_anchor_repo.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('jangkar terbaru terisolasi per pengguna dan verifikasi tersimpan', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: DatabaseMigrations.schemaVersion,
        onCreate: DatabaseMigrations.create));
    addTearDown(db.close);
    final repo = ChainAnchorRepository(db);
    await repo.save(userId: 'u1', seq: 1, status: 'pending', txHash: 'tx1');
    await repo.save(userId: 'u1', seq: 2, status: 'confirmed',
      headHash: List.filled(64, 'a').join(), userKey: 'key', txHash: 'tx2');
    await repo.save(userId: 'u2', seq: 3, status: 'confirmed');
    expect((await repo.latest('u1'))?.seq, 2);
    expect((await repo.latest('u2'))?.seq, 3);
    await repo.saveVerification('u1', 2, 'unknown');
    expect((await repo.latest('u1'))?.verifyResult, 'unknown');
    await repo.setRetryAfter('u1', DateTime.utc(2026, 10, 24, 12));
    expect(await repo.retryAfter('u1'), DateTime.utc(2026, 10, 24, 12));
    await repo.clear('u1');
    expect(await repo.latest('u1'), isNull);
    expect(await repo.retryAfter('u1'), isNull);
    expect((await repo.latest('u2'))?.seq, 3);
  });
}
