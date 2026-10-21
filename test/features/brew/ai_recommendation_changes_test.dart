import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/app_database.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/db/database_provider.dart';
import 'package:tetes/data/remote/ai_client.dart';
import 'package:tetes/data/repositories/bean_repo.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/features/auth/state/auth_providers.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/brew/ai_brew.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/brew_plan.dart';
import 'package:tetes/features/brew/state/ai_client_provider.dart';
import 'package:tetes/features/brew/state/brew_setup_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  final original = BrewCalculator.createDefault(beanId: 'bean-1');

  test('daftar perubahan memuat lima parameter yang berubah', () {
    final recommended = BrewCalculator.createDefault(
      beanId: original.beanId,
      doseG: original.doseG == 16 ? 17 : 16,
      ratio: original.ratio == 17 ? 18 : 17,
      waterTempC: original.waterTempC == 93 ? 94 : 93,
      grind: Grind.values.firstWhere((grind) => grind != original.grind),
      pouringCount: original.pouringCount == 4 ? 5 : 4,
    );

    final changes = AiBrew.recommendationChanges(original, recommended);
    expect(changes.map((change) => change.field), [
      AiPlanField.dose,
      AiPlanField.ratio,
      AiPlanField.temperature,
      AiPlanField.grind,
      AiPlanField.pouring,
    ]);
    expect(changes.first.before, isNot(changes.first.after));
    expect(changes.last.label, 'Jumlah pouring');
  });

  test('rencana yang sama menghasilkan daftar perubahan kosong', () {
    expect(AiBrew.recommendationChanges(original, original), isEmpty);
  });

  test('Kembalikan memakai rencana lama beserta tahap yang disunting', () {
    final before = BrewCalculator.updateDuration(
      original,
      stageIndex: 1,
      durationSeconds: 45,
    );
    final recommended = BrewCalculator.createDefault(
      beanId: original.beanId,
      waterTempC: original.waterTempC == 93 ? 94 : 93,
    );
    final suggestion = AppliedAiSuggestion(
      before: before,
      recommended: recommended,
      note: 'Coba suhu lain.',
      hasHistory: true,
    );

    expect(suggestion.highlights(AiPlanField.temperature), isTrue);
    expect(
      suggestion
          .markEdited(AiPlanField.temperature)
          .highlights(AiPlanField.temperature),
      isFalse,
    );
    expect(identical(suggestion.restore(), before), isTrue);
    expect(suggestion.restore().stages[1].durationSeconds, 45);
  });

  test('502 sibuk memulai jeda 30 detik dan mencegah ketuk ganda', () async {
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
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    var calls = 0;
    final client = AiClient(
      sessionStorage: storage,
      client: MockClient((_) {
        calls++;
        started.complete();
        return pending.future;
      }),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(AsyncData(database)),
        sessionStorageProvider.overrideWithValue(storage),
        aiClientProvider.overrideWithValue(client),
      ],
    );
    final provider = brewSetupControllerProvider(beanId);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(() async {
      subscription.close();
      container.dispose();
      client.close();
      await database.close();
    });
    await container.read(provider.future);
    final controller = container.read(provider.notifier);

    final first = controller.recommend(isScreenCurrent: () => true);
    await started.future;
    await controller.recommend(isScreenCurrent: () => true);
    expect(calls, 1);
    pending.complete(
      http.Response(
        jsonEncode({
          'error': {
            'code': 'ai_upstream_error',
            'details': {'upstream_status': 503},
          },
        }),
        502,
      ),
    );
    await first;
    final state = container.read(provider).requireValue;
    expect(state.aiCooldownSeconds, 30);
    expect(
      state.notice,
      contains('Layanan AI sedang sibuk, coba lagi sebentar'),
    );
    await controller.recommend(isScreenCurrent: () => true);
    expect(calls, 1);
  });
}

class _SessionStorage implements SessionStorage {
  @override
  Future<StoredSession?> readSession() async => const StoredSession(
    token: 'token-uji',
    userId: 'user-1',
    expiresAt: '2099-01-01T00:00:00Z',
  );

  @override
  Future<void> clearSession() async {}

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
