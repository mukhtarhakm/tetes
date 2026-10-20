import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/remote/sync_client.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/data/sync/sync_service.dart';

const user = '11111111-1111-4111-8111-111111111111';
const otherUser = '22222222-2222-4222-8222-222222222222';
const beanId = '33333333-3333-4333-8333-333333333333';
const brewId = '44444444-4444-4444-8444-444444444444';
const timestamp = '2026-10-20T01:00:00Z';

class _Storage implements SessionStorage {
  @override
  Future<StoredSession?> readSession() async => const StoredSession(
    token: 'test-token',
    userId: user,
    expiresAt: timestamp,
  );
  @override
  Future<void> saveSession({
    required String token,
    required String userId,
    required String expiresAt,
  }) async {}
  @override
  Future<void> clearSession() async {}
  @override
  Future<List<String>> readPendingRevokeTokens() async => [];
  @override
  Future<void> writePendingRevokeTokens(List<String> tokens) async {}
}

class _Call {
  _Call(this.beans, this.brews);
  final List<Map<String, Object?>> beans;
  final List<Map<String, Object?>> brews;
}

class _FakeClient extends SyncClient {
  _FakeClient() : super(sessionStorage: _Storage());
  final calls = <_Call>[];
  Future<SyncPushResponse> Function(_Call call)? answer;

  @override
  Future<SyncPushResponse> push({
    required String userId,
    required List<Map<String, Object?>> beans,
    required List<Map<String, Object?>> brews,
  }) async {
    final call = _Call(beans, brews);
    calls.add(call);
    if (answer != null) return answer!(call);
    return SyncPushResponse(
      accepted: {
        'beans': beans.map((row) => row['id'] as String).toList(),
        'brews': brews.map((row) => row['id'] as String).toList(),
      },
      rejected: const [],
    );
  }
}

Future<Database> _database() async {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: DatabaseMigrations.schemaVersion,
      onCreate: DatabaseMigrations.create,
    ),
  );
}

Future<void> _bean(
  Database db,
  String id, {
  String userId = user,
  String status = 'pending',
  int archived = 0,
}) async {
  await db.insert('beans', {
    'id': id,
    'user_id': userId,
    'name': 'Biji',
    'species': 'arabika',
    'is_self_roasted': 0,
    'initial_stock_g': 100.0,
    'archived': archived,
    'created_at': timestamp,
    'updated_at': timestamp,
    'sync_status': status,
  });
}

Future<void> _brew(
  Database db,
  String id,
  int seq, {
  String userId = user,
  String status = 'pending',
}) async {
  await db.insert('brews', {
    'id': id,
    'user_id': userId,
    'seq': seq,
    'bean_id': beanId,
    'brewed_at_utc': timestamp,
    'dose_g': 15.0,
    'ratio': 16.0,
    'water_temp_c': 92,
    'grind': 'sedang',
    'total_time_s': 195,
    'taste_score': 3,
    'taste_tags': 'asam,cokelat',
    'status': 'aktif',
    'prev_hash': seq == 1 ? '0' : 'prev-$seq',
    'hash': 'hash-$seq',
    'created_at': timestamp,
    'sync_status': status,
  });
  await db.insert('brew_stages', {
    'id': '55555555-5555-4555-8555-${seq.toString().padLeft(12, '0')}',
    'brew_id': id,
    'position': 1,
    'name': 'bloom',
    'target_start_s': 0,
    'target_duration_s': 30,
    'target_water_cum_g': 45.0,
    'target_pour_g': 45.0,
  });
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('SyncClient sends token without apikey and parses response', () async {
    final client = SyncClient(
      sessionStorage: _Storage(),
      baseUrl: 'https://example.test/functions/v1',
      client: MockClient((request) async {
        expect(request.url.path, '/functions/v1/sync-push');
        expect(request.headers['x-session-token'], 'test-token');
        expect(request.headers.containsKey('apikey'), isFalse);
        expect(request.headers['content-type'], 'application/json');
        expect(jsonDecode(request.body), {'beans': [], 'brews': []});
        return http.Response(
          '{"accepted":{"beans":[],"brews":[]},"rejected":[]}',
          200,
        );
      }),
    );
    final response = await client.push(userId: user, beans: [], brews: []);
    expect(response.rejected, isEmpty);
  });

  test('SyncClient classifies HTTP 400, 401, and 500', () async {
    for (final entry in {
      400: SyncFailure.badRequest,
      401: SyncFailure.unauthorized,
      500: SyncFailure.server,
    }.entries) {
      final client = SyncClient(
        sessionStorage: _Storage(),
        client: MockClient((_) async => http.Response('{}', entry.key)),
      );
      await expectLater(
        client.push(userId: user, beans: [], brews: []),
        throwsA(
          isA<SyncException>().having(
            (error) => error.failure,
            'failure',
            entry.value,
          ),
        ),
      );
    }
  });

  test(
    'beans go first, booleans and nulls map, stages follow, user is isolated',
    () async {
      final db = await _database();
      final client = _FakeClient();
      addTearDown(() async {
        client.close();
        await db.close();
      });
      await _bean(db, beanId);
      await _bean(
        db,
        '66666666-6666-4666-8666-666666666666',
        userId: otherUser,
      );
      await _brew(db, brewId, 1);
      final service = SyncService(db, client, () async {});
      await service.run(userId: user);
      expect(client.calls, hasLength(2));
      expect(client.calls.first.beans, hasLength(1));
      expect(client.calls.first.beans.single['archived'], false);
      expect(client.calls.first.beans.single['is_self_roasted'], false);
      expect(client.calls.first.beans.single['bean_type'], isNull);
      expect(client.calls.last.brews.single['stages'], isA<List>());
      expect((client.calls.last.brews.single['stages'] as List), hasLength(1));
      expect(client.calls.last.brews.single['hash'], 'hash-1');
      expect(client.calls.last.brews.single['prev_hash'], '0');
      expect(client.calls.last.brews.single['brewed_at_utc'], timestamp);
      expect(
        (await db.query(
          'brews',
          columns: ['hash', 'prev_hash', 'seq', 'sync_status'],
        )).single,
        {'hash': 'hash-1', 'prev_hash': '0', 'seq': 1, 'sync_status': 'synced'},
      );
      expect(
        (await db.query(
          'beans',
          where: 'user_id = ?',
          whereArgs: [otherUser],
        )).single['sync_status'],
        'pending',
      );
    },
  );

  test('batch limits and ascending seq', () async {
    final db = await _database();
    final client = _FakeClient();
    addTearDown(() async {
      client.close();
      await db.close();
    });
    await _bean(db, beanId);
    for (var i = 0; i < 100; i++) {
      await _bean(
        db,
        'aaaaaaaa-aaaa-4aaa-8aaa-${i.toString().padLeft(12, '0')}',
      );
    }
    for (var i = 51; i >= 1; i--) {
      await _brew(
        db,
        'bbbbbbbb-bbbb-4bbb-8bbb-${i.toString().padLeft(12, '0')}',
        i,
      );
    }
    await SyncService(db, client, () async {}).run(userId: user);
    expect(client.calls.map((call) => call.beans.length), [100, 1, 0, 0]);
    expect(client.calls.map((call) => call.brews.length), [0, 0, 50, 1]);
    expect(
      client.calls[2].brews.map((row) => row['seq']),
      List.generate(50, (i) => i + 1),
    );
  });

  test('first rejected brew is error; chain blocked remains pending', () async {
    final db = await _database();
    final client = _FakeClient();
    addTearDown(() async {
      client.close();
      await db.close();
    });
    await _bean(db, beanId, status: 'synced');
    for (var i = 1; i <= 3; i++) {
      await _brew(
        db,
        'bbbbbbbb-bbbb-4bbb-8bbb-${i.toString().padLeft(12, '0')}',
        i,
      );
    }
    client.answer = (call) async => SyncPushResponse(
      accepted: const {'beans': [], 'brews': []},
      rejected: [
        SyncRejection('brews', call.brews[0]['id'] as String, 'chain_broken'),
        for (final row in call.brews.skip(1))
          SyncRejection('brews', row['id'] as String, 'chain_blocked'),
      ],
    );
    await SyncService(db, client, () async {}).run(userId: user);
    expect(client.calls, hasLength(1));
    final rows = await db.query(
      'brews',
      columns: ['sync_status'],
      orderBy: 'seq',
    );
    expect(rows.map((row) => row['sync_status']), [
      'error',
      'pending',
      'pending',
    ]);
    final settings = await db.query(
      'settings',
      where: 'user_id = ?',
      whereArgs: [user],
    );
    final values = {for (final row in settings) row['key']: row['value']};
    expect(
      values['last_sync_at'],
      matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$')),
    );
    expect(
      (jsonDecode(values['last_sync_summary'] as String) as Map)['rejected'],
      {'chain_broken': 1, 'chain_blocked': 2},
    );
    expect(SyncService.reasonMessages['chain_broken'], contains('rantai'));
  });

  test(
    'network failure preserves pending; unauthorized calls force logout',
    () async {
      final db = await _database();
      final client = _FakeClient();
      addTearDown(() async {
        client.close();
        await db.close();
      });
      await _bean(db, beanId);
      var logoutCalls = 0;
      final service = SyncService(db, client, () async {
        logoutCalls++;
      });
      client.answer = (_) async => throw const SyncException(
        SyncFailure.network,
        'Tidak dapat terhubung ke internet.',
      );
      await expectLater(
        service.run(userId: user),
        throwsA(isA<SyncException>()),
      );
      expect((await db.query('beans')).single['sync_status'], 'pending');
      expect(logoutCalls, 0);
      client.answer = (_) async => throw const SyncException(
        SyncFailure.unauthorized,
        'Sesi tidak sah.',
      );
      await expectLater(
        service.run(userId: user),
        throwsA(isA<SyncException>()),
      );
      expect(logoutCalls, 1);
      expect((await db.query('beans')).single['sync_status'], 'pending');
    },
  );

  test('timeout, 400, and 500 preserve local status', () async {
    final db = await _database();
    final client = _FakeClient();
    addTearDown(() async {
      client.close();
      await db.close();
    });
    await _bean(db, beanId);
    final service = SyncService(db, client, () async {});
    for (final failure in [
      SyncFailure.timeout,
      SyncFailure.badRequest,
      SyncFailure.server,
    ]) {
      client.answer = (_) async => throw SyncException(failure, 'Coba lagi.');
      await expectLater(
        service.run(userId: user),
        throwsA(isA<SyncException>()),
      );
      expect((await db.query('beans')).single['sync_status'], 'pending');
    }
  });

  test('second sync cannot send while first is active', () async {
    final db = await _database();
    final client = _FakeClient();
    addTearDown(() async {
      client.close();
      await db.close();
    });
    await _bean(db, beanId);
    final gate = Completer<void>();
    client.answer = (call) async {
      await gate.future;
      return SyncPushResponse(
        accepted: {
          'beans': [call.beans.single['id'] as String],
          'brews': [],
        },
        rejected: const [],
      );
    };
    final service = SyncService(db, client, () async {});
    final first = service.run(userId: user);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await expectLater(service.run(userId: user), throwsA(isA<SyncException>()));
    gate.complete();
    await first;
    expect(client.calls, hasLength(1));
  });

  test('manual retries error rows; automatic sends only pending', () async {
    final db = await _database();
    final client = _FakeClient();
    addTearDown(() async {
      client.close();
      await db.close();
    });
    await _bean(db, beanId, status: 'error');
    final service = SyncService(db, client, () async {});
    await service.run(userId: user);
    expect(client.calls, isEmpty);
    await service.run(userId: user, retryErrors: true);
    expect(client.calls.single.beans.single['id'], beanId);
    expect((await db.query('beans')).single['sync_status'], 'synced');
  });
}
