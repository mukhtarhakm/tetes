import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/app_database.dart';
import 'package:tetes/core/notifications/notification_service.dart';
import '../../core/notifications/fake_notification_service.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/db/database_provider.dart';
import 'package:tetes/data/remote/ai_client.dart';
import 'package:tetes/data/repositories/bean_repo.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/features/auth/state/auth_providers.dart';
import 'package:tetes/features/auth/state/session_controller.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/brew/ai_brew.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/state/ai_client_provider.dart';
import 'package:tetes/features/brew/state/brew_setup_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('cooldown bersama langsung aktif selama 30 detik', () {
    final cooldown = AiRequestCooldown();
    addTearDown(cooldown.dispose);
    var seconds = 0;
    cooldown.start((value) => seconds = value);
    expect(cooldown.active, isTrue);
    expect(seconds, 30);
  });

  test('rencana awal dari layar lain dipakai, bukan pengaturan terbaik', () async {
    // Seperti di aplikasi: controller belum hidup di root saat layar
    // Atur Seduh dibuka di dalam ProviderScope yang meng-override rencana.
    final harness = await _harness(
      MockClient((_) async => http.Response('{}', 500)),
      warmUp: false,
    );
    addTearDown(harness.dispose);
    final custom = BrewCalculator.createDefault(
      beanId: harness.beanId,
      waterTempC: 95,
      pouringCount: 4,
    );
    final scoped = ProviderContainer(
      parent: harness.container,
      overrides: [initialBrewPlanProvider.overrideWithValue(custom)],
    );
    addTearDown(scoped.dispose);
    final provider = brewSetupControllerProvider(harness.beanId);
    final subscription = scoped.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    final state = await scoped.read(provider.future);
    expect(state.plan!.waterTempC, 95);
    expect(state.plan!.pouringCount, 4);
  });

  test(
    'jumlah pouring AI diterapkan dan Kembalikan memulihkan rencana',
    () async {
      final suggestion = Map<String, dynamic>.of(_recommendation);
      suggestion['pouring_count'] = 2;
      suggestion['stages'] = [
        {'name': 'bloom', 'start_s': 0, 'duration_s': 40, 'water_cum_g': 45},
        {
          'name': 'pouring_2',
          'start_s': 40,
          'duration_s': 60,
          'water_cum_g': 240,
        },
      ];
      final harness = await _harness(
        MockClient((_) async => http.Response(jsonEncode(suggestion), 200)),
      );
      addTearDown(harness.dispose);
      final provider = brewSetupControllerProvider(harness.beanId);
      final before = harness.container.read(provider).requireValue.plan!;

      await harness.controller.recommend(isScreenCurrent: () => true);
      final applied = harness.container.read(provider).requireValue;
      expect(applied.plan!.pouringCount, 2);
      expect(applied.aiSuggestion!.highlights(AiPlanField.pouring), isTrue);
      expect(applied.aiSuggestion!.changes.last.label, 'Pouring');

      harness.controller.restoreBeforeAi();
      final restored = harness.container.read(provider).requireValue;
      expect(identical(restored.plan, before), isTrue);
      expect(restored.aiSuggestion, isNull);
    },
  );

  test('respons AI terlambat tidak menimpa perubahan form', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final harness = await _harness(
      MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    addTearDown(harness.dispose);

    final request = harness.controller.recommend(isScreenCurrent: () => true);
    await started.future;
    harness.controller.updateTemperature('93');
    response.complete(http.Response(jsonEncode(_recommendation), 200));
    await request;

    final state = harness.container
        .read(brewSetupControllerProvider(harness.beanId))
        .requireValue;
    expect(state.plan!.waterTempC, 93);
    expect(state.isAiLoading, isFalse);
  });

  test('respons AI saat layar ditinggalkan tidak mengubah rencana', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    var screenCurrent = true;
    final harness = await _harness(
      MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    addTearDown(harness.dispose);

    final request = harness.controller.recommend(
      isScreenCurrent: () => screenCurrent,
    );
    await started.future;
    screenCurrent = false;
    response.complete(http.Response(jsonEncode(_recommendation), 200));
    await request;

    final state = harness.container
        .read(brewSetupControllerProvider(harness.beanId))
        .requireValue;
    expect(state.plan!.waterTempC, 92);
    expect(state.isAiLoading, isFalse);
  });

  test('401 dari AI menghapus sesi melalui keluar paksa', () async {
    final harness = await _harness(
      MockClient(
        (_) async => http.Response(
          '{"error":{"code":"unauthorized","message":"Sesi tidak sah","details":{}}}',
          401,
        ),
      ),
    );
    addTearDown(harness.dispose);

    await harness.controller.recommend(isScreenCurrent: () => true);

    expect(harness.storage.session, isNull);
    expect(
      harness.container.read(sessionControllerProvider).requireValue.status,
      SessionStatus.unauthenticated,
    );
  });

  test('401 terlambat tetap menghapus sesi setelah form berubah', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final harness = await _harness(
      MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    addTearDown(harness.dispose);

    final request = harness.controller.recommend(isScreenCurrent: () => true);
    await started.future;
    harness.controller.updateTemperature('93');
    response.complete(http.Response('', 401));
    await request;

    expect(harness.storage.session, isNull);
    expect(
      harness.container.read(sessionControllerProvider).requireValue.status,
      SessionStatus.unauthenticated,
    );
  });

  test('401 akun lama tidak menghapus sesi akun baru', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final harness = await _harness(
      MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    addTearDown(harness.dispose);

    final request = harness.controller.recommend(isScreenCurrent: () => true);
    await started.future;
    harness.storage.session = const StoredSession(
      token: 'token-baru',
      userId: 'user-2',
      expiresAt: '2099-01-01T00:00:00Z',
    );
    response.complete(http.Response('', 401));
    await request;

    expect(harness.storage.session?.userId, 'user-2');
  });
}

const _recommendation = {
  'dose_g': 15,
  'ratio': 16,
  'water_temp_c': 95,
  'grind': 'sedang',
  'pouring_count': 3,
  'stages': [
    {'name': 'bloom', 'start_s': 0, 'duration_s': 40, 'water_cum_g': 45},
    {'name': 'pouring_2', 'start_s': 40, 'duration_s': 30, 'water_cum_g': 143},
    {'name': 'pouring_3', 'start_s': 70, 'duration_s': 30, 'water_cum_g': 240},
  ],
  'note': 'Titik awal uji.',
};

Future<_Harness> _harness(
  MockClient httpClient, {
  bool warmUp = true,
}) async {
  final database = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: DatabaseMigrations.schemaVersion,
      onConfigure: AppDatabase.configureDatabase,
      onCreate: DatabaseMigrations.create,
    ),
  );
  final beanId = await BeanRepository(database).create(
    userId: 'user-1',
    draft: const BeanDraft(
      name: 'Biji Uji',
      species: BeanSpecies.arabika,
      isSelfRoasted: false,
      initialStockG: 250,
      roasteryNotesTags: [],
    ),
  );
  final storage = _SessionStorage();
  final client = AiClient(sessionStorage: storage, client: httpClient);
  final container = ProviderContainer(
    overrides: [
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      databaseProvider.overrideWithValue(AsyncData(database)),
      sessionStorageProvider.overrideWithValue(storage),
      aiClientProvider.overrideWithValue(client),
    ],
  );
  ProviderSubscription<AsyncValue<BrewSetupState>>? subscription;
  if (warmUp) {
    final provider = brewSetupControllerProvider(beanId);
    subscription = container.listen(provider, (_, _) {});
    await container.read(provider.future);
  }
  return _Harness(database, container, beanId, subscription, storage, client);
}

class _Harness {
  _Harness(
    this.database,
    this.container,
    this.beanId,
    this.subscription,
    this.storage,
    this.client,
  );

  final Database database;
  final ProviderContainer container;
  final String beanId;
  final ProviderSubscription<AsyncValue<BrewSetupState>>? subscription;
  final _SessionStorage storage;
  final AiClient client;

  BrewSetupController get controller =>
      container.read(brewSetupControllerProvider(beanId).notifier);

  Future<void> dispose() async {
    subscription?.close();
    container.dispose();
    client.close();
    await database.close();
  }
}

class _SessionStorage implements SessionStorage {
  StoredSession? session = const StoredSession(
    token: 'token-uji',
    userId: 'user-1',
    expiresAt: '2099-01-01T00:00:00Z',
  );

  @override
  Future<StoredSession?> readSession() async => session;

  @override
  Future<void> clearSession() async {
    session = null;
  }

  @override
  Future<List<String>> readPendingRevokeTokens() async => [];

  @override
  Future<void> writePendingRevokeTokens(List<String> tokens) async {}

  @override
  Future<void> saveSession({
    required String token,
    required String userId,
    required String expiresAt,
  }) async {}
}
