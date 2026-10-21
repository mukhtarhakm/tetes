import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:tetes/core/utils/hash.dart';
import 'package:tetes/data/remote/sync_client.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/data/sync/sync_service.dart';

const user = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';
const beanId = '33333333-3333-4333-8333-333333333333';
const time = '2026-10-21T08:30:00Z';

class FakeClient extends SyncClient {
  FakeClient(this.answer)
    : super(sessionStorage: const SecureSessionStorage(FlutterSecureStorage()));

  Future<SyncPullResponse> Function(int, String?) answer;
  @override
  Future<SyncPullResponse> pullData({
    required String userId,
    required int lastSeq,
    required String? lastHash,
  }) => answer(lastSeq, lastHash);
  @override
  void close() {}
}

Map<String, dynamic> bean() => {
  'id': beanId,
  'name': 'Asli server',
  'species': 'arabika',
  'bean_type': null,
  'arabica_percent': null,
  'roastery': null,
  'is_self_roasted': false,
  'origin': null,
  'process': null,
  'process_custom': null,
  'roast_level': null,
  'roast_date': null,
  'pack_size_g': null,
  'price_original': null,
  'currency': null,
  'fx_rate': null,
  'fx_date': null,
  'price_idr_per_kg': null,
  'initial_stock_g': 100.0,
  'roastery_notes_tags': null,
  'roastery_notes_text': null,
  'best_brew_id': null,
  'archived': false,
  'created_at': time,
  'updated_at': time,
};

Map<String, dynamic> brew(int seq, String prevHash, {String? hashOverride}) {
  final hash = hashEntry((
    beanId: beanId,
    doseG: 15.0,
    ratio: 16.0,
    waterTempC: 92,
    grind: 'sedang',
    totalTimeS: 195,
    tasteScore: seq + 2,
    tasteTags: ['asam'],
    brewedAtUtc: time,
  ), prevHash);
  return {
    'id': '00000000-0000-4000-8000-${seq.toString().padLeft(12, '0')}',
    'seq': seq,
    'bean_id': beanId,
    'brewed_at_utc': time,
    'dose_g': 15.0,
    'ratio': 16.0,
    'water_temp_c': 92,
    'grind': 'sedang',
    'total_time_s': 195,
    'taste_score': seq + 2,
    'taste_tags': 'asam',
    'notes': null,
    'ai_advice': null,
    'cost_idr': null,
    'status': 'aktif',
    'prev_hash': prevHash,
    'hash': hashOverride ?? hash,
    'created_at': time,
    'stages': [
      {
        'id': '10000000-0000-4000-8000-${seq.toString().padLeft(12, '0')}',
        'brew_id': '00000000-0000-4000-8000-${seq.toString().padLeft(12, '0')}',
        'position': 1,
        'name': 'bloom',
        'target_start_s': 0,
        'target_duration_s': 30,
        'target_water_cum_g': 30.0,
        'target_pour_g': 30.0,
        'actual_start_s': null,
        'actual_duration_s': null,
        'actual_water_g': null,
        'drawdown_s': null,
      },
    ],
  };
}

SyncPullResponse page(
  String status, {
  List<Map<String, dynamic>>? beans,
  List<Map<String, dynamic>>? brews,
  bool more = false,
  int serverSeq = 2,
}) => SyncPullResponse(
  status: status,
  serverLastSeq: serverSeq,
  hasMore: more,
  beans: beans ?? [],
  brews: brews ?? [],
);

Future<Database> database() async {
  final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  await db.execute(
    'CREATE TABLE settings (user_id TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(user_id,key))',
  );
  await db.execute(
    '''CREATE TABLE beans (
    id TEXT PRIMARY KEY, user_id TEXT NOT NULL, name TEXT NOT NULL, species TEXT NOT NULL,
    bean_type TEXT, arabica_percent INTEGER, roastery TEXT, is_self_roasted INTEGER NOT NULL,
    origin TEXT, process TEXT, process_custom TEXT, roast_level TEXT, roast_date TEXT,
    pack_size_g REAL, price_original REAL, currency TEXT, fx_rate REAL, fx_date TEXT,
    price_idr_per_kg REAL, initial_stock_g REAL NOT NULL, roastery_notes_tags TEXT,
    roastery_notes_text TEXT, best_brew_id TEXT, archived INTEGER NOT NULL,
    created_at TEXT NOT NULL, updated_at TEXT NOT NULL, sync_status TEXT NOT NULL)''',
  );
  await db.execute(
    '''CREATE TABLE brews (
    id TEXT PRIMARY KEY, user_id TEXT NOT NULL, seq INTEGER NOT NULL, bean_id TEXT NOT NULL,
    brewed_at_utc TEXT NOT NULL, dose_g REAL NOT NULL, ratio REAL NOT NULL,
    water_temp_c INTEGER NOT NULL, grind TEXT NOT NULL, total_time_s INTEGER NOT NULL,
    taste_score INTEGER NOT NULL, taste_tags TEXT NOT NULL, notes TEXT, ai_advice TEXT,
    cost_idr REAL, status TEXT NOT NULL, prev_hash TEXT NOT NULL, hash TEXT NOT NULL,
    created_at TEXT NOT NULL, sync_status TEXT NOT NULL, UNIQUE(user_id,seq))''',
  );
  await db.execute(
    '''CREATE TABLE brew_stages (
    id TEXT PRIMARY KEY, brew_id TEXT NOT NULL, position INTEGER NOT NULL, name TEXT NOT NULL,
    target_start_s INTEGER NOT NULL, target_duration_s INTEGER NOT NULL,
    target_water_cum_g REAL NOT NULL, target_pour_g REAL NOT NULL,
    actual_start_s INTEGER, actual_duration_s INTEGER, actual_water_g REAL, drawdown_s INTEGER)''',
  );
  return db;
}

Future<void> seedBrew(
  Database db,
  Map<String, dynamic> value, {
  String userId = user,
}) async {
  final row = Map<String, Object?>.of(value)..remove('stages');
  await db.insert('brews', {
    ...row,
    'user_id': userId,
    'sync_status': 'synced',
  });
}

void main() {
  sqfliteFfiInit();
  late Database db;
  setUp(() async => db = await database());
  tearDown(() async => db.close());

  test(
    'lokal kosong menarik banyak halaman dan menghitung best brew',
    () async {
      final first = brew(1, '0');
      final second = brew(2, first['hash'] as String);
      final seen = <int>[];
      final client = FakeClient((seq, hash) async {
        seen.add(seq);
        return seq == 0
            ? page('pull', beans: [bean()], brews: [first], more: true)
            : page('pull', beans: [bean()], brews: [second]);
      });
      await SyncService(db, client, () async {}).pull(user);
      expect(seen, [0, 1]);
      expect((await db.query('brews')).length, 2);
      expect((await db.query('brew_stages')).length, 2);
      expect((await db.query('beans')).single['best_brew_id'], second['id']);
      expect((await db.query('beans')).single['sync_status'], 'pending');
      expect(
        (await db.query(
          'brews',
        )).every((row) => row['sync_status'] == 'synced'),
        isTrue,
      );
    },
  );

  test('prefix menarik suffix tanpa mengubah biji dan seduhan lama', () async {
    final first = brew(1, '0');
    final second = brew(2, first['hash'] as String);
    await db.insert('beans', {
      ...bean(),
      'name': 'Nama lokal',
      'is_self_roasted': 0,
      'archived': 0,
      'user_id': user,
      'sync_status': 'pending',
    });
    await seedBrew(db, {...first, 'notes': 'Catatan lokal'});
    final client = FakeClient((seq, hash) async {
      expect(seq, 1);
      expect(hash, first['hash']);
      return page('pull', beans: [bean()], brews: [second]);
    });
    await SyncService(db, client, () async {}).pull(user);
    expect((await db.query('beans')).single['name'], 'Nama lokal');
    expect(
      (await db.query('brews', where: 'seq = 1')).single['notes'],
      'Catatan lokal',
    );
    expect((await db.query('brews')).length, 2);
  });

  test(
    'halaman kedua gagal, prefix tetap ada dan pull ulang lanjut dari sana',
    () async {
      final first = brew(1, '0');
      final second = brew(2, first['hash'] as String);
      var fail = true;
      final seen = <int>[];
      final client = FakeClient((seq, hash) async {
        seen.add(seq);
        if (seq == 0) {
          return page('pull', beans: [bean()], brews: [first], more: true);
        }
        if (fail) {
          throw const SyncException(SyncFailure.network, 'Jaringan putus.');
        }
        expect(hash, first['hash']);
        return page('pull', beans: [bean()], brews: [second]);
      });
      final service = SyncService(db, client, () async {});
      await expectLater(service.pull(user), throwsA(isA<SyncException>()));
      expect((await db.query('brews')).length, 1);
      fail = false;
      await service.pull(user);
      expect(seen, [0, 1, 1]);
      expect((await db.query('brews')).length, 2);
    },
  );

  test('status tanpa data dan diverged tidak mengubah data', () async {
    for (final status in [
      'up_to_date',
      'local_ahead',
      'diverged',
      'empty_server',
    ]) {
      final client = FakeClient((_, _) async => page(status, serverSeq: 0));
      final service = SyncService(db, client, () async {});
      if (status == 'diverged') {
        await expectLater(service.pull(user), throwsA(isA<SyncException>()));
      } else {
        await service.pull(user);
      }
      expect(await db.query('brews'), isEmpty);
    }
  });

  test('empty_server menarik biji tanpa seduhan dan 413 jelas', () async {
    final client = FakeClient(
      (_, _) async => page('empty_server', beans: [bean()], serverSeq: 0),
    );
    await SyncService(db, client, () async {}).pull(user);
    expect((await db.query('beans')).single['sync_status'], 'synced');
    expect((await db.query('beans')).single['is_self_roasted'], 0);
    client.answer = (_, _) async => throw const SyncException(
      SyncFailure.tooManyBeans,
      'Jumlah biji di server melebihi batas 500.',
    );
    await expectLater(
      SyncService(db, client, () async {}).pull(user),
      throwsA(
        predicate(
          (error) =>
              error is SyncException &&
              error.failure == SyncFailure.tooManyBeans,
        ),
      ),
    );
    expect((await db.query('beans')).length, 1);
  });

  test('hash salah menolak seluruh halaman', () async {
    final bad = brew(1, '0', hashOverride: '0' * 64);
    final service = SyncService(
      db,
      FakeClient((_, _) async => page('pull', beans: [bean()], brews: [bad])),
      () async {},
    );
    await expectLater(
      service.pull(user),
      throwsA(
        predicate(
          (error) =>
              error is SyncException &&
              error.message == 'Data dari server tidak lolos verifikasi.',
        ),
      ),
    );
    expect(await db.query('beans'), isEmpty);
    expect(await db.query('brews'), isEmpty);
  });

  test('transaksi gagal tidak menyisakan biji atau seduhan', () async {
    final invalid = brew(1, '0');
    (invalid['stages'] as List).first['position'] = 2;
    final service = SyncService(
      db,
      FakeClient(
        (_, _) async => page('pull', beans: [bean()], brews: [invalid]),
      ),
      () async {},
    );
    await expectLater(service.pull(user), throwsA(isA<SyncException>()));
    expect(await db.query('beans'), isEmpty);
    expect(await db.query('brews'), isEmpty);
  });

  test(
    'jaringan gagal dan 401 tanpa perubahan data; 401 keluar paksa',
    () async {
      var logout = 0;
      final client = FakeClient(
        (_, _) async =>
            throw const SyncException(SyncFailure.network, 'Jaringan putus.'),
      );
      await expectLater(
        SyncService(db, client, () async {
          logout++;
        }).pull(user),
        throwsA(isA<SyncException>()),
      );
      expect(logout, 0);
      client.answer = (_, _) async => throw const SyncException(
        SyncFailure.unauthorized,
        'Sesi tidak sah.',
      );
      await expectLater(
        SyncService(db, client, () async {
          logout++;
        }).pull(user),
        throwsA(isA<SyncException>()),
      );
      expect(logout, 1);
      expect(await db.query('brews'), isEmpty);
    },
  );

  test(
    'pengguna lain tidak terpengaruh dan pull terkunci terhadap push',
    () async {
      await db.insert('beans', {
        ...bean(),
        'is_self_roasted': 0,
        'archived': 0,
        'user_id': other,
        'sync_status': 'synced',
      });
      final gate = Completer<SyncPullResponse>();
      final service = SyncService(
        db,
        FakeClient((_, _) => gate.future),
        () async {},
      );
      final running = service.pull(user);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await expectLater(
        service.run(userId: user),
        throwsA(isA<SyncException>()),
      );
      gate.complete(page('up_to_date'));
      await running;
      final collision = SyncService(
        db,
        FakeClient(
          (_, _) async => page('empty_server', beans: [bean()], serverSeq: 0),
        ),
        () async {},
      );
      await expectLater(collision.pull(user), throwsA(isA<SyncException>()));
      expect((await db.query('beans')).single['user_id'], other);
    },
  );
}
