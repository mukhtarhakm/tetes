import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/database_provider.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/features/auth/state/auth_providers.dart';
import 'package:tetes/main.dart';

void main() {
  late Database database;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('menampilkan login setelah database siap', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(AsyncData(database)),
          sessionStorageProvider.overrideWithValue(_FakeSessionStorage(null)),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Masuk ke Tetes'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('session valid membuka shell tanpa jaringan', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Belum ada seduhan. Alat bantu seduh akan hadir di sini.'),
      findsOneWidget,
    );
    expect(find.text('Masuk ke Tetes'), findsNothing);
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
          databaseProvider.overrideWithValue(AsyncData(database)),
          sessionStorageProvider.overrideWithValue(storage),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(storage.wasCleared, isTrue);
    expect(
      find.text(
        'Sesi telah berakhir. Internet diperlukan untuk masuk kembali.',
      ),
      findsOneWidget,
    );
  });
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
