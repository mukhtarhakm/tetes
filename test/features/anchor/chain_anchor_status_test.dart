import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/db/database_provider.dart';
import 'package:tetes/data/remote/anchor_client.dart';
import 'package:tetes/data/repositories/chain_anchor_repo.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/features/anchor/state/chain_anchor_status.dart';
import 'package:tetes/features/auth/state/auth_providers.dart';
import 'package:tetes/features/auth/state/session_controller.dart';

class _Storage implements SessionStorage {
  String userId = 'user-1';
  @override
  Future<StoredSession?> readSession() async => StoredSession(
    token: 'token', userId: userId, expiresAt: '2099-01-01T00:00:00Z');
  @override
  Future<void> clearSession() async {}
  @override
  Future<List<String>> readPendingRevokeTokens() async => [];
  @override
  Future<void> saveSession({required String token, required String userId, required String expiresAt}) async {}
  @override
  Future<void> writePendingRevokeTokens(List<String> tokens) async {}
}

class _Client extends AnchorClient {
  _Client(SessionStorage storage) : super(sessionStorage: storage);
  final pending = Completer<AnchorResult>();
  final started = Completer<void>();
  int calls = 0;
  @override
  Future<AnchorResult> requestAnchor(String userId) {
    calls++;
    if (!started.isCompleted) started.complete();
    return pending.future;
  }
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('tidak paralel dan hasil dibuang bila pengguna berganti', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: DatabaseMigrations.schemaVersion,
        onCreate: DatabaseMigrations.create));
    addTearDown(db.close);
    final storage = _Storage();
    final client = _Client(storage);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
      sessionStorageProvider.overrideWithValue(storage),
      anchorClientProvider.overrideWithValue(client),
    ]);
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);
    await container.read(chainAnchorStatusProvider.future);
    final controller = container.read(chainAnchorStatusProvider.notifier);
    final first = controller.requestAfterPush('user-1');
    await client.started.future;
    final second = controller.requestAfterPush('user-1');
    expect(client.calls, 1);
    storage.userId = 'user-2';
    container.read(sessionControllerProvider.notifier).markAuthenticated('user-2');
    client.pending.complete(const Confirmed(seq: 1,
      headHash: 'abc', userKey: 'key', explorerUrl: 'https://example.invalid'));
    await Future.wait([first, second]);
    expect(await (await container.read(chainAnchorRepositoryProvider.future)).latest('user-1'), isNull);
  });

  test('Retry-After tersimpan dan mencegah permintaan berikutnya', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: DatabaseMigrations.schemaVersion,
        onCreate: DatabaseMigrations.create));
    addTearDown(db.close);
    final storage = _Storage();
    final client = _Client(storage);
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWith((ref) async => db),
      sessionStorageProvider.overrideWithValue(storage),
      anchorClientProvider.overrideWithValue(client),
    ]);
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);
    await container.read(chainAnchorStatusProvider.future);
    final controller = container.read(chainAnchorStatusProvider.notifier);
    final first = controller.requestAfterPush('user-1');
    await client.started.future;
    client.pending.complete(const RateLimited(Duration(minutes: 5)));
    await first;
    await controller.requestAfterPush('user-1');
    expect(client.calls, 1);
    expect(await (await container.read(chainAnchorRepositoryProvider.future)).retryAfter('user-1'), isNotNull);
  });
}
