import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}

AuthClient _successfulAuthClient() {
  return AuthClient(
    client: MockClient(
      (_) async => http.Response(
        jsonEncode({
          'user': {
            'id': 'be159fad-b283-4ff1-ab73-1aa47418d755',
            'username': 'rais_uji',
            'created_at': '2026-10-19T01:00:00.456789Z',
          },
          'session_token': 'token-rahasia',
          'expires_at': '2026-10-26T01:00:00Z',
        }),
        200,
      ),
    ),
  );
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
