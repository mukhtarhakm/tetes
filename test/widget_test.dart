import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/db/database_provider.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/features/auth/biometric/biometric_authenticator.dart';
import 'package:tetes/features/auth/state/auth_providers.dart';
import 'package:tetes/main.dart';
import 'package:tetes/core/notifications/notification_service.dart';
import 'package:tetes/core/notifications/notification_coordinator.dart';
import 'core/notifications/fake_notification_service.dart';

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

  testWidgets('menampilkan login setelah database siap', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          databaseProvider.overrideWithValue(AsyncData(database)),
          sessionStorageProvider.overrideWithValue(_FakeSessionStorage(null)),
          biometricAuthenticatorProvider.overrideWithValue(
            _FakeBiometricAuthenticator(available: false),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await _pumpAsyncUi(tester);

    expect(find.text('Masuk ke Tetes'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('session valid membuka shell tanpa jaringan', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          notificationCoordinatorProvider.overrideWith(
            (ref) async => FakeNotificationCoordinator(),
          ),
          databaseProvider.overrideWithValue(AsyncData(database)),
          sessionStorageProvider.overrideWithValue(
            _FakeSessionStorage(
              const StoredSession(
                token: 'token-rahasia',
                userId: 'user-1',
                expiresAt: '2099-01-01T00:00:00Z',
              ),
            ),
          ),
          biometricAuthenticatorProvider.overrideWithValue(
            _FakeBiometricAuthenticator(available: false),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await _pumpAsyncUi(tester);

    expect(find.text('Biji kopi'), findsOneWidget);
    expect(find.text('Masuk ke Tetes'), findsNothing);
  });

  testWidgets('gerbang biometrik tidak membangun shell sebelum berhasil', (
    tester,
  ) async {
    await tester.runAsync(
      () => database.insert('settings', {
        'user_id': 'user-1',
        'key': 'biometric_enabled',
        'value': '1',
      }),
    );
    final authenticator = _FakeBiometricAuthenticator(available: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          databaseProvider.overrideWithValue(AsyncData(database)),
          sessionStorageProvider.overrideWithValue(
            _FakeSessionStorage(
              const StoredSession(
                token: 'token-rahasia',
                userId: 'user-1',
                expiresAt: '2099-01-01T00:00:00Z',
              ),
            ),
          ),
          biometricAuthenticatorProvider.overrideWithValue(authenticator),
        ],
        child: const MyApp(),
      ),
    );
    await _pumpAsyncUi(tester);

    expect(find.text('Buka Tetes'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.text('Biji kopi'), findsNothing);
    expect(authenticator.authenticationAttempts, 1);

    await tester.pump();
    expect(authenticator.authenticationAttempts, 1);
  });

  testWidgets('biometrik yang tidak tersedia hanya menawarkan password', (
    tester,
  ) async {
    await tester.runAsync(
      () => database.insert('settings', {
        'user_id': 'user-1',
        'key': 'biometric_enabled',
        'value': '1',
      }),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          databaseProvider.overrideWithValue(AsyncData(database)),
          sessionStorageProvider.overrideWithValue(
            _FakeSessionStorage(
              const StoredSession(
                token: 'token-rahasia',
                userId: 'user-1',
                expiresAt: '2099-01-01T00:00:00Z',
              ),
            ),
          ),
          biometricAuthenticatorProvider.overrideWithValue(
            _FakeBiometricAuthenticator(available: false),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await _pumpAsyncUi(tester);

    expect(find.text('Pakai password'), findsOneWidget);
    expect(find.text('Coba lagi'), findsNothing);
    expect(find.text('Biji kopi'), findsNothing);
  });

  testWidgets('session kedaluwarsa dibersihkan dan menampilkan pesan', (
    tester,
  ) async {
    final storage = _FakeSessionStorage(
      const StoredSession(
        token: 'token-rahasia',
        userId: 'user-1',
        expiresAt: '2020-01-01T00:00:00Z',
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(
            FakeNotificationService(),
          ),
          databaseProvider.overrideWithValue(AsyncData(database)),
          sessionStorageProvider.overrideWithValue(storage),
          biometricAuthenticatorProvider.overrideWithValue(
            _FakeBiometricAuthenticator(available: false),
          ),
        ],
        child: const MyApp(),
      ),
    );
    await _pumpAsyncUi(tester);

    expect(storage.wasCleared, isTrue);
    expect(
      find.text(
        'Sesi telah berakhir. Internet diperlukan untuk masuk kembali.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpAsyncUi(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  for (var frame = 0; frame < 8; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  _FakeBiometricAuthenticator({required this.available});

  final bool available;
  int authenticationAttempts = 0;

  @override
  Future<BiometricAuthenticationOutcome> authenticate() async {
    authenticationAttempts++;
    return BiometricAuthenticationOutcome.canceled;
  }

  @override
  Future<bool> isAvailable() async => available;
}

class _FakeSessionStorage implements SessionStorage {
  _FakeSessionStorage(this._session);

  StoredSession? _session;
  bool wasCleared = false;
  List<String> pendingTokens = [];

  @override
  Future<void> clearSession() async {
    wasCleared = true;
    _session = null;
  }

  @override
  Future<StoredSession?> readSession() async => _session;

  @override
  Future<List<String>> readPendingRevokeTokens() async => [...pendingTokens];

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
