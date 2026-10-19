import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/data/remote/auth_client.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/features/auth/session/session_revocation_queue.dart';
import 'package:tetes/features/auth/state/auth_providers.dart';
import 'package:tetes/features/auth/state/session_controller.dart';

void main() {
  test('logout mengantrekan token sebelum menghapus session aktif', () async {
    final storage = _RecordingSessionStorage(_validSession());
    final response = Completer<void>();
    final client = _InspectingClient(storage, response.future);
    final queue = SessionRevocationQueue(client, storage);
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        sessionRevocationQueueProvider.overrideWithValue(queue),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);

    await container.read(sessionControllerProvider.notifier).logout();

    expect(storage.operations, ['write_pending', 'clear_active']);
    expect(
      container.read(sessionControllerProvider).requireValue.status,
      SessionStatus.unauthenticated,
    );
    expect(client.sawQueuedToken, isTrue);
    expect(storage.pendingTokens, ['token-1']);

    response.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(storage.pendingTokens, isEmpty);
  });

  test('startup menyelesaikan logout yang terputus setelah antre', () async {
    final storage = _RecordingSessionStorage(_validSession())
      ..pendingTokens = ['token-1'];
    final client = _InspectingClient(storage, Future.value());
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        sessionRevocationQueueProvider.overrideWithValue(
          SessionRevocationQueue(client, storage),
        ),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(sessionControllerProvider.future);

    expect(state.status, SessionStatus.unauthenticated);
    expect(storage.activeSession, isNull);
    expect(storage.operations.first, 'clear_active');
  });

  test('keluar paksa 401 tidak memasukkan token ke antrean', () async {
    final storage = _RecordingSessionStorage(_validSession());
    final client = _InspectingClient(storage, Future.value());
    final container = ProviderContainer(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        sessionRevocationQueueProvider.overrideWithValue(
          SessionRevocationQueue(client, storage),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);

    await container.read(sessionControllerProvider.notifier).forceLogout();

    expect(storage.pendingTokens, isEmpty);
    expect(client.callCount, 0);
  });
}

StoredSession _validSession() {
  return const StoredSession(
    token: 'token-1',
    userId: 'user-1',
    expiresAt: '2099-01-01T00:00:00Z',
  );
}

class _InspectingClient implements SessionRevocationClient {
  _InspectingClient(this._storage, this._response);

  final _RecordingSessionStorage _storage;
  final Future<void> _response;
  int callCount = 0;
  bool sawQueuedToken = false;

  @override
  Future<void> revokeSession({
    required String token,
    Duration? requestTimeout,
  }) async {
    callCount++;
    sawQueuedToken = _storage.pendingTokens.contains(token);
    await _response;
  }
}

class _RecordingSessionStorage implements SessionStorage {
  _RecordingSessionStorage(this.activeSession);

  StoredSession? activeSession;
  List<String> pendingTokens = [];
  final List<String> operations = [];

  @override
  Future<void> clearSession() async {
    operations.add('clear_active');
    activeSession = null;
  }

  @override
  Future<List<String>> readPendingRevokeTokens() async => [...pendingTokens];

  @override
  Future<StoredSession?> readSession() async => activeSession;

  @override
  Future<void> saveSession({
    required String token,
    required String userId,
    required String expiresAt,
  }) async {
    activeSession = StoredSession(
      token: token,
      userId: userId,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> writePendingRevokeTokens(List<String> tokens) async {
    operations.add('write_pending');
    pendingTokens = [...tokens];
  }
}
