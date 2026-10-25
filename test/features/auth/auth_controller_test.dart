import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/db/database_provider.dart';
import 'package:tetes/data/remote/auth_client.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/features/auth/state/auth_controller.dart';
import 'package:tetes/features/auth/state/auth_providers.dart';
import 'package:tetes/features/auth/biometric/biometric_authenticator.dart';

void main() {
  late Database database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseMigrations.create(database, DatabaseMigrations.schemaVersion);
  });

  tearDown(() async {
    await database.close();
  });

  test('biometrik ditolak OS tidak mencoba login atau menghitung kegagalan', () async {
    final client = AuthClient(baseUrl: 'https://example.test/rest/v1',
      apiKey: 'public-test-key', client: MockClient((_) async => fail('HTTP tidak boleh dipanggil')));
    final container = ProviderContainer(overrides: [
      authClientProvider.overrideWithValue(client),
      biometricAuthenticatorProvider.overrideWithValue(_DeniedBiometric()),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(authControllerProvider.notifier)
        .loginBiometric('rais_uji'), isFalse);
    expect(container.read(authControllerProvider).errorMessage,
        'Pemeriksaan sidik jari dibatalkan.');
  });

  test(
    'gagal secure storage membuat login gagal tanpa menyimpan password',
    () async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(AsyncData(database)),
          authClientProvider.overrideWithValue(_successfulAuthClient()),
          sessionStorageProvider.overrideWithValue(
            const _FailingSessionStorage(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final succeeded = await container
          .read(authControllerProvider.notifier)
          .login(username: 'rais_uji', password: 'rahasia123');

      expect(succeeded, isFalse);
      expect(
        container.read(authControllerProvider).errorMessage,
        'Sesi tidak dapat disimpan dengan aman. Silakan coba lagi.',
      );
      expect(
        container.read(authControllerProvider).toString(),
        isNot(contains('rahasia123')),
      );
      final users = await database.query('users');
      expect(users.single['created_at'], '2026-10-19T01:00:00Z');
    },
  );

  test('register dengan akun tersimpan tetapi sesi gagal meminta layar login', () async {
    final client = AuthClient(
      baseUrl: 'https://example.test/rest/v1',
      apiKey: 'public-test-key',
      rateLimitStorage: _MemoryStorage(),
      client: MockClient((request) async => request.url.path.endsWith('/users')
          ? http.Response(jsonEncode([{
              'id': 'be159fad-b283-4ff1-ab73-1aa47418d755',
              'username': 'rais_uji',
              'created_at': '2026-10-19T01:00:00Z',
            }]), 201)
          : http.Response('', 500)),
    );
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(AsyncData(database)),
      authClientProvider.overrideWithValue(client),
      sessionStorageProvider.overrideWithValue(const _FailingSessionStorage()),
    ]);
    addTearDown(container.dispose);

    final succeeded = await container.read(authControllerProvider.notifier)
        .register(username: 'rais_uji', password: 'rahasia123');
    expect(succeeded, isFalse);
    expect(container.read(authControllerProvider).requiresLogin, isTrue);
    expect(container.read(authControllerProvider).errorMessage,
        'Akun dibuat. Silakan masuk.');
  });
}

class _DeniedBiometric implements BiometricAuthenticator {
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<BiometricAuthenticationOutcome> authenticate() async =>
      BiometricAuthenticationOutcome.canceled;
}

AuthClient _successfulAuthClient() {
  return AuthClient(
    baseUrl: 'https://example.test/rest/v1',
    apiKey: 'public-test-key',
    rateLimitStorage: _MemoryStorage(),
    client: MockClient(
      (request) async => request.url.path.endsWith('/users')
          ? http.Response(
              jsonEncode([{
            'id': 'be159fad-b283-4ff1-ab73-1aa47418d755',
            'username': 'rais_uji',
            'created_at': '2026-10-19T01:00:00.456789Z',
            'salt': 'AAECAwQFBgcICQoLDA0ODw==',
            'password_hash': 'BYdeqGJjr60TVfaaOv4dkfeaGbnAsHyBfFh8k/sKBps=',
            'iterations': 1000,
            'algo': 'pbkdf2-hmac-sha256',
          }]), 200)
          : http.Response('', 201),
    ),
  );
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

class _FailingSessionStorage implements SessionStorage {
  const _FailingSessionStorage();

  @override
  Future<void> clearSession() async {}

  @override
  Future<StoredSession?> readSession() async => null;

  @override
  Future<List<String>> readPendingRevokeTokens() async => const [];

  @override
  Future<void> saveSession({
    required String token,
    required String userId,
    required String expiresAt,
  }) {
    throw const SessionStorageException();
  }

  @override
  Future<void> writePendingRevokeTokens(List<String> tokens) async {}
}
