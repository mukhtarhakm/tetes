import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tetes/data/remote/auth_client.dart';

void main() {
  const successBody = {
    'user': {
      'id': 'be159fad-b283-4ff1-ab73-1aa47418d755',
      'username': 'rais_uji',
      'created_at': '2026-10-19T01:00:00Z',
    },
    'session_token': 'token-rahasia',
    'expires_at': '2026-10-26T01:00:00Z',
  };

  test('login mengirim body JSON tanpa apikey atau debug timing', () async {
    late http.Request capturedRequest;
    final client = AuthClient(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode(successBody), 200);
      }),
      baseUrl: 'https://example.com/functions/v1',
    );

    final session = await client.login(
      username: 'rais_uji',
      password: 'rahasia123',
    );

    expect(capturedRequest.url.path, endsWith('/auth-login'));
    expect(capturedRequest.headers.containsKey('apikey'), isFalse);
    expect(capturedRequest.headers.containsKey('x-debug-timing'), isFalse);
    expect(jsonDecode(capturedRequest.body), {
      'username': 'rais_uji',
      'password': 'rahasia123',
    });
    expect(session.user.username, 'rais_uji');
    expect(session.token, 'token-rahasia');
  });

  test('register memakai endpoint auth-register', () async {
    late http.Request capturedRequest;
    final client = AuthClient(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(jsonEncode(successBody), 200);
      }),
      baseUrl: 'https://example.com/functions/v1',
    );

    await client.register(username: 'rais_uji', password: 'rahasia123');

    expect(capturedRequest.url.path, endsWith('/auth-register'));
  });

  test('400 memetakan galat per kolom', () async {
    final client = _clientForResponse(400, {
      'error': {
        'code': 'invalid_input',
        'message': 'Data tidak valid.',
        'details': {
          'fields': {'username': 'Username tidak valid.'},
        },
      },
    });

    await expectLater(
      client.register(username: 'RAIS', password: 'rahasia123'),
      throwsA(
        isA<AuthException>()
            .having((error) => error.type, 'type', AuthFailureType.invalidInput)
            .having(
              (error) => error.fieldErrors['username'],
              'username',
              'Username tidak valid.',
            ),
      ),
    );
  });

  test('401 selalu menjadi pesan kredensial umum', () async {
    final client = _clientForResponse(401, {
      'error': {
        'code': 'invalid_credentials',
        'message': 'Detail yang tidak boleh ditampilkan.',
        'details': {},
      },
    });

    await expectLater(
      client.login(username: 'rais_uji', password: 'password_salah'),
      throwsA(
        isA<AuthException>()
            .having(
              (error) => error.type,
              'type',
              AuthFailureType.invalidCredentials,
            )
            .having(
              (error) => error.message,
              'message',
              'Username atau password salah',
            ),
      ),
    );
  });

  test('409 menjadi galat username sudah digunakan', () async {
    final client = _clientForResponse(409, {
      'error': {
        'code': 'username_taken',
        'message': 'Username sudah digunakan.',
        'details': {},
      },
    });

    await expectLater(
      client.register(username: 'rais_uji', password: 'rahasia123'),
      throwsA(
        isA<AuthException>()
            .having(
              (error) => error.type,
              'type',
              AuthFailureType.usernameTaken,
            )
            .having(
              (error) => error.fieldErrors['username'],
              'username',
              'Username sudah digunakan.',
            ),
      ),
    );
  });

  test('429 membulatkan retry_after_s ke atas dalam menit', () async {
    final client = _clientForResponse(429, {
      'error': {
        'code': 'login_rate_limited',
        'message': 'Terlalu banyak percobaan.',
        'details': {'retry_after_s': 61},
      },
    });

    await expectLater(
      client.login(username: 'rais_uji', password: 'password_salah'),
      throwsA(
        isA<AuthException>()
            .having((error) => error.retryAfterMinutes, 'minutes', 2)
            .having(
              (error) => error.message,
              'message',
              'Terlalu banyak percobaan login. Coba lagi dalam 2 menit.',
            ),
      ),
    );
  });

  test('ClientException menjadi galat jaringan', () async {
    final client = AuthClient(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );

    await expectLater(
      client.login(username: 'rais_uji', password: 'rahasia123'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.type,
          'type',
          AuthFailureType.network,
        ),
      ),
    );
  });

  test('permintaan melewati batas waktu menjadi galat timeout', () async {
    final client = AuthClient(
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(jsonEncode(successBody), 200);
      }),
      timeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      client.login(username: 'rais_uji', password: 'rahasia123'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.type,
          'type',
          AuthFailureType.timeout,
        ),
      ),
    );
  });

  test('respons sukses yang rusak menjadi galat server', () async {
    final client = AuthClient(
      client: MockClient((_) async => http.Response('{}', 200)),
    );

    await expectLater(
      client.login(username: 'rais_uji', password: 'rahasia123'),
      throwsA(
        isA<AuthException>().having(
          (error) => error.type,
          'type',
          AuthFailureType.server,
        ),
      ),
    );
  });
}

AuthClient _clientForResponse(int statusCode, Map<String, Object?> body) {
  return AuthClient(
    client: MockClient(
      (_) async => http.Response(jsonEncode(body), statusCode),
    ),
  );
}
