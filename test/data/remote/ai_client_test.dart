import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tetes/data/remote/ai_client.dart';
import 'package:tetes/data/secure/session_storage.dart';

void main() {
  const userId = 'user-1';
  const payload = <String, Object?>{
    'bean': {'name': 'Flores'},
  };

  test('chat mengirim pesan dan context serta membaca sisa kuota', () async {
    late http.Request captured;
    final client = AiClient(
      sessionStorage: _MemorySessionStorage(),
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"reply":"Coba suhu 92°C.","remaining_today":19}',
          200,
        );
      }),
    );
    final result = await client.chat(
      userId: userId,
      messages: [
        {'role': 'user', 'content': 'Suhu?'},
      ],
      context: {
        'bean': {'name': 'Flores'},
      },
    );
    expect(jsonDecode(captured.body), {
      'type': 'chat',
      'payload': {
        'messages': [
          {'role': 'user', 'content': 'Suhu?'},
        ],
        'context': {
          'bean': {'name': 'Flores'},
        },
      },
    });
    expect(result.reply, 'Coba suhu 92°C.');
    expect(result.remainingToday, 19);
  });

  test('chat menolak respons rusak dan menampilkan galat 429', () async {
    for (final body in [
      '{}',
      '{"reply":" "}',
      '{"reply":"ok","remaining_today":21}',
    ]) {
      await expectLater(
        _clientForResponse(200, body).chat(
          userId: userId,
          messages: [
            {'role': 'user', 'content': 'Halo'},
          ],
        ),
        throwsA(
          isA<AiException>().having(
            (error) => error.failure,
            'failure',
            AiFailure.invalidOutput,
          ),
        ),
      );
    }
    await expectLater(
      _clientForResponse(
        429,
        '{"error":{"details":{"retry_after_s":60}}}',
      ).chat(
        userId: userId,
        messages: [
          {'role': 'user', 'content': 'Halo'},
        ],
      ),
      throwsA(
        isA<AiException>()
            .having((error) => error.failure, 'failure', AiFailure.rateLimited)
            .having((error) => error.message, 'message', contains('besok')),
      ),
    );
  });

  test(
    'mengirim token hanya di header dan payload JSON ke endpoint ai',
    () async {
      late http.Request captured;
      final client = AiClient(
        sessionStorage: _MemorySessionStorage(),
        client: MockClient((request) async {
          captured = request;
          return http.Response('{"note":"ok"}', 200);
        }),
        baseUrl: 'https://example.com/functions/v1',
      );

      final response = await client.recommend(userId: userId, payload: payload);

      expect(client.timeout, const Duration(seconds: 35));
      expect(captured.url.path, '/functions/v1/ai');
      expect(captured.headers['x-session-token'], 'secret-token');
      expect(captured.headers.containsKey('apikey'), isFalse);
      expect(jsonDecode(captured.body), {
        'type': 'recommend',
        'payload': payload,
      });
      expect(captured.body, isNot(contains('secret-token')));
      expect(response['note'], 'ok');
    },
  );

  test('401 dipetakan sebagai sesi tidak sah', () async {
    final client = _clientForResponse(401, '{}');
    await expectLater(
      client.diagnose(userId: userId, payload: payload),
      throwsA(
        isA<AiException>().having(
          (error) => error.failure,
          'failure',
          AiFailure.unauthorized,
        ),
      ),
    );
  });

  test('429 menyertakan retry_after_s tanpa memakai pesan server', () async {
    final client = _clientForResponse(
      429,
      jsonEncode({
        'error': {
          'message': 'rahasia',
          'details': {'retry_after_s': 44},
        },
      }),
    );
    await expectLater(
      client.recommend(userId: userId, payload: payload),
      throwsA(
        isA<AiException>()
            .having((error) => error.failure, 'failure', AiFailure.rateLimited)
            .having((error) => error.retryAfterSeconds, 'retry', 44)
            .having((error) => error.message, 'message', contains('1 menit')),
      ),
    );
  });

  test('server_configuration_error memberi pesan layanan belum siap', () async {
    final client = _clientForResponse(
      500,
      jsonEncode({
        'error': {'code': 'server_configuration_error'},
      }),
    );
    await expectLater(
      client.recommend(userId: userId, payload: payload),
      throwsA(
        isA<AiException>()
            .having((error) => error.failure, 'failure', AiFailure.server)
            .having(
              (error) => error.message,
              'message',
              contains('belum siap'),
            ),
      ),
    );
  });

  test(
    '502 ai_invalid_output dan JSON rusak dipetakan untuk fallback',
    () async {
      final upstream = _clientForResponse(
        502,
        jsonEncode({
          'error': {'code': 'ai_invalid_output'},
        }),
      );
      final malformed = _clientForResponse(200, 'not-json');
      for (final client in [upstream, malformed]) {
        await expectLater(
          client.recommend(userId: userId, payload: payload),
          throwsA(
            isA<AiException>().having(
              (error) => error.failure,
              'failure',
              AiFailure.invalidOutput,
            ),
          ),
        );
      }
    },
  );

  test('502 meneruskan upstream_status numerik bila tersedia', () async {
    for (final status in [503, 429]) {
      final client = _clientForResponse(
        502,
        jsonEncode({
          'error': {
            'code': 'ai_upstream_error',
            'details': {'upstream_status': status},
          },
        }),
      );
      await expectLater(
        client.recommend(userId: userId, payload: payload),
        throwsA(
          isA<AiException>()
              .having((error) => error.failure, 'failure', AiFailure.upstream)
              .having((error) => error.upstreamStatus, 'status', status),
        ),
      );
    }
    final withoutStatus = _clientForResponse(502, '{}');
    await expectLater(
      withoutStatus.recommend(userId: userId, payload: payload),
      throwsA(
        isA<AiException>()
            .having((error) => error.upstreamStatus, 'status', isNull)
            .having(
              (error) => error.message,
              'message',
              'Layanan AI sedang bermasalah. Pengaturan cadangan tersedia.',
            ),
      ),
    );
  });

  test('permintaan timeout dipetakan tanpa bocor body', () async {
    final pending = Completer<http.Response>();
    final client = AiClient(
      sessionStorage: _MemorySessionStorage(),
      client: MockClient((_) => pending.future),
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      client.recommend(userId: userId, payload: payload),
      throwsA(
        isA<AiException>().having(
          (error) => error.failure,
          'failure',
          AiFailure.timeout,
        ),
      ),
    );
  });

  test('session user lain tidak mengirim permintaan', () async {
    var requested = false;
    final client = AiClient(
      sessionStorage: _MemorySessionStorage(),
      client: MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      client.recommend(userId: 'other-user', payload: payload),
      throwsA(
        isA<AiException>().having(
          (error) => error.failure,
          'failure',
          AiFailure.unauthorized,
        ),
      ),
    );
    expect(requested, isFalse);
  });
}

AiClient _clientForResponse(int status, String body) => AiClient(
  sessionStorage: _MemorySessionStorage(),
  client: MockClient((_) async => http.Response(body, status)),
);

class _MemorySessionStorage implements SessionStorage {
  @override
  Future<StoredSession?> readSession() async => const StoredSession(
    token: 'secret-token',
    userId: 'user-1',
    expiresAt: '2026-10-22T00:00:00Z',
  );

  @override
  Future<void> saveSession({
    required String token,
    required String userId,
    required String expiresAt,
  }) async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<List<String>> readPendingRevokeTokens() async => [];

  @override
  Future<void> writePendingRevokeTokens(List<String> tokens) async {}
}
