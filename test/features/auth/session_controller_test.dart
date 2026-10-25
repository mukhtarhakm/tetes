import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tetes/core/notifications/notification_service.dart';
import 'package:tetes/data/remote/auth_client.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/data/secure/biometric_credential_storage.dart';
import 'package:tetes/data/repositories/chain_anchor_repo.dart';
import 'package:tetes/features/auth/session/session_revocation_queue.dart';
import 'package:tetes/features/auth/state/auth_providers.dart';
import 'package:tetes/features/auth/state/session_controller.dart';

void main() {
  test('logout mengantrekan token sebelum menghapus session aktif', () async {
    final biometricStorage = BiometricCredentialStorage(_MemoryStorage());
    await biometricStorage.save(const BiometricCredential(
      username: 'rais_uji', passwordHash: 'hash', salt: 'salt',
      iterations: 1, algo: 'pbkdf2-hmac-sha256'));
    final storage = _RecordingSessionStorage(_validSession());
    final response = Completer<void>();
    final client = _InspectingClient(storage, response.future);
    final queue = SessionRevocationQueue(client, storage);
    final notifications = _FakeNotificationService();
    final container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        sessionStorageProvider.overrideWithValue(storage),
        sessionRevocationQueueProvider.overrideWithValue(queue),
        clearChainAnchorsProvider.overrideWithValue((_) async {}),
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
    expect(notifications.cancelCount, 1);
    expect(await biometricStorage.read('rais_uji'), isNotNull);

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
        notificationServiceProvider.overrideWithValue(
          _FakeNotificationService(),
        ),
        sessionStorageProvider.overrideWithValue(storage),
        sessionRevocationQueueProvider.overrideWithValue(
          SessionRevocationQueue(client, storage),
        ),
        clearChainAnchorsProvider.overrideWithValue((_) async {}),
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
    final notifications = _FakeNotificationService();
    final container = ProviderContainer(
      overrides: [
        notificationServiceProvider.overrideWithValue(notifications),
        sessionStorageProvider.overrideWithValue(storage),
        sessionRevocationQueueProvider.overrideWithValue(
          SessionRevocationQueue(client, storage),
        ),
        clearChainAnchorsProvider.overrideWithValue((_) async {}),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sessionControllerProvider.future);

    await container.read(sessionControllerProvider.notifier).forceLogout();

    expect(storage.pendingTokens, isEmpty);
    expect(client.callCount, 0);
    expect(notifications.cancelCount, 1);
  });
}

class _MemoryStorage implements FlutterSecureStorage {
  final values = <String, String>{};
  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String;
    if (invocation.memberName == #read) return Future<String?>.value(values[key]);
    if (invocation.memberName == #write) {
      values[key] = invocation.namedArguments[#value] as String;
      return Future<void>.value();
    }
    if (invocation.memberName == #delete) {
      values.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeNotificationService extends NotificationService {
  int cancelCount = 0;
  @override
  Future<void> cancelAll() async {
    cancelCount++;
  }
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
