import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/data/remote/auth_client.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/features/auth/session/session_revocation_queue.dart';

void main() {
  test(
    'token sudah antre saat request dan dihapus hanya setelah sukses',
    () async {
      final storage = _MemorySessionStorage();
      final response = Completer<void>();
      late SessionRevocationQueue queue;
      final client = _FakeRevocationClient((token, _) async {
        expect(storage.pendingTokens, contains(token));
        await response.future;
      });
      queue = SessionRevocationQueue(client, storage);

      await queue.enqueue('token-1');
      final revocation = queue.revokeQueuedToken('token-1');
      await Future<void>.delayed(Duration.zero);

      expect(storage.pendingTokens, ['token-1']);
      response.complete();
      expect(await revocation, RevocationResult.revoked);
      expect(storage.pendingTokens, isEmpty);
    },
  );

  test('pencabutan gagal mempertahankan token di antrean', () async {
    final storage = _MemorySessionStorage();
    final client = _FakeRevocationClient((_, _) async {
      throw const AuthException(
        type: AuthFailureType.network,
        message: 'offline',
      );
    });
    final queue = SessionRevocationQueue(client, storage);

    await queue.enqueue('token-1');
    final result = await queue.revokeQueuedToken('token-1');

    expect(result, RevocationResult.deferred);
    expect(storage.pendingTokens, ['token-1']);
  });

  test('token tersimpan dihapus setelah retry berikutnya berhasil', () async {
    final storage = _MemorySessionStorage()..pendingTokens = ['token-1'];
    final client = _FakeRevocationClient((_, _) async {});
    final queue = SessionRevocationQueue(client, storage);

    final result = await queue.retryPending();

    expect(result, RevocationResult.revoked);
    expect(storage.pendingTokens, isEmpty);
    expect(client.callCount, 1);
  });

  test('retry tanpa antrean tidak memanggil klien', () async {
    final storage = _MemorySessionStorage();
    final client = _FakeRevocationClient((_, _) async {});
    final queue = SessionRevocationQueue(client, storage);

    final result = await queue.retryPending();

    expect(result, RevocationResult.nothingPending);
    expect(client.callCount, 0);
  });

  test('antrean maksimal lima token dan membuang yang terlama', () async {
    final storage = _MemorySessionStorage();
    final client = _FakeRevocationClient((_, _) async {});
    final queue = SessionRevocationQueue(client, storage);

    for (var index = 1; index <= 6; index++) {
      await queue.enqueue('token-$index');
    }

    expect(storage.pendingTokens, [
      'token-2',
      'token-3',
      'token-4',
      'token-5',
      'token-6',
    ]);
  });
}

class _FakeRevocationClient implements SessionRevocationClient {
  _FakeRevocationClient(this._onRevoke);

  final Future<void> Function(String token, Duration? timeout) _onRevoke;
  int callCount = 0;

  @override
  Future<void> revokeSession({
    required String token,
    Duration? requestTimeout,
  }) {
    callCount++;
    return _onRevoke(token, requestTimeout);
  }
}

class _MemorySessionStorage implements SessionStorage {
  List<String> pendingTokens = [];

  @override
  Future<void> clearSession() async {}

  @override
  Future<List<String>> readPendingRevokeTokens() async => [...pendingTokens];

  @override
  Future<StoredSession?> readSession() async => null;

  @override
  Future<void> saveSession({
    required String token,
    required String userId,
    required String expiresAt,
  }) async {}

  @override
  Future<void> writePendingRevokeTokens(List<String> tokens) async {
    pendingTokens = [...tokens];
  }
}
