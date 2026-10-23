import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/db/database_migrations.dart';
import 'package:tetes/data/db/database_provider.dart';
import 'package:tetes/data/remote/ai_client.dart';
import 'package:tetes/data/repositories/bean_repo.dart';
import 'package:tetes/data/repositories/chat_repo.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/features/auth/state/auth_providers.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/brew/state/ai_client_provider.dart';
import 'package:tetes/features/chat/chat_context.dart';
import 'package:tetes/features/chat/chat_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);

  test('context hanya memuat field yang diizinkan server', () async {
    final database = await _database();
    try {
      final repo = BeanRepository(database);
      final id = await repo.create(
        userId: 'user-1',
        draft: const BeanDraft(
          name: 'Biji',
          species: BeanSpecies.arabika,
          isSelfRoasted: false,
          initialStockG: 100,
          roasteryNotesTags: [],
          priceOriginal: 200000,
        ),
      );
      final bean = (await repo.findById(userId: 'user-1', id: id))!;
      final context = buildChatContext(
        bean: bean,
        bestPlan: null,
        recentBrews: [
          {
            'brewed_at_utc': '2026-10-23T00:00:00Z',
            'dose_g': 15.0,
            'ratio': 16.0,
            'water_temp_c': 92,
            'grind': 'sedang',
            'taste_score': 4,
            'taste_tags': 'manis',
            'hash': 'secret',
            'user_id': 'user-1',
          },
        ],
      );
      final encoded = jsonEncode(context);
      expect(encoded, isNot(contains('secret')));
      expect(encoded, isNot(contains('user_id')));
      expect(encoded, isNot(contains('price')));
      expect((context['recent_brews'] as List), hasLength(1));
    } finally {
      await database.close();
    }
  });

  test('send valid, gagal, 429, dan percakapan baru', () async {
    final database = await _database();
    final storage = _Storage();
    var response = http.Response(
      '{"reply":"Coba suhu 92°C.","remaining_today":19}',
      200,
    );
    final requests = <http.Request>[];
    final client = AiClient(
      sessionStorage: storage,
      client: MockClient((request) async {
        requests.add(request);
        return response;
      }),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(AsyncData(database)),
        sessionStorageProvider.overrideWithValue(storage),
        aiClientProvider.overrideWithValue(client),
      ],
    );
    final subscription = container.listen(chatControllerProvider, (_, _) {});
    try {
      await container.read(chatControllerProvider.future);
      final controller = container.read(chatControllerProvider.notifier);
      await controller.send('  ');
      expect(
        container.read(chatControllerProvider).requireValue.errorMessage,
        contains('1 sampai 500'),
      );
      expect(requests, isEmpty);
      await controller.send('  Suhu?  ');
      var state = container.read(chatControllerProvider).requireValue;
      expect(state.messages.map((item) => item.content), [
        'Suhu?',
        'Coba suhu 92°C.',
      ]);
      expect(state.remainingToday, 19);
      expect(jsonDecode(requests.single.body)['payload']['messages'], [
        {'role': 'user', 'content': 'Suhu?'},
      ]);
      response = http.Response(
        '{"error":{"details":{"retry_after_s":40}}}',
        429,
      );
      await controller.send('Lagi?');
      state = container.read(chatControllerProvider).requireValue;
      expect(state.messages.last.content, 'Lagi?');
      expect(state.messages.last.failed, isTrue);
      expect(state.errorMessage, contains('besok'));
      response = http.Response('error', 502);
      await controller.send('Kenapa?');
      state = container.read(chatControllerProvider).requireValue;
      expect(state.messages.last.failed, isTrue);
      expect(
        state.messages.where((item) => item.role == 'assistant'),
        hasLength(1),
      );
      await ChatRepository(
        database,
      ).add(userId: 'user-2', role: 'user', content: 'Milik user lain');
      await controller.newConversation();
      expect(
        container.read(chatControllerProvider).requireValue.messages,
        isEmpty,
      );
      expect(
        (await ChatRepository(database).list('user-2')).single.content,
        'Milik user lain',
      );
    } finally {
      subscription.close();
      container.dispose();
      client.close();
      await database.close();
    }
  });
}

Future<Database> _database() => databaseFactoryFfi.openDatabase(
  inMemoryDatabasePath,
  options: OpenDatabaseOptions(
    version: DatabaseMigrations.schemaVersion,
    onCreate: DatabaseMigrations.create,
    onUpgrade: DatabaseMigrations.migrate,
  ),
);

class _Storage implements SessionStorage {
  StoredSession? session = const StoredSession(
    token: 'test-token',
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
  Future<void> saveSession({
    required String token,
    required String userId,
    required String expiresAt,
  }) async {
    session = StoredSession(token: token, userId: userId, expiresAt: expiresAt);
  }

  @override
  Future<List<String>> readPendingRevokeTokens() async => [];
  @override
  Future<void> writePendingRevokeTokens(List<String> tokens) async {}
}
