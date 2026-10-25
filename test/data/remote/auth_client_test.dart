import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tetes/data/remote/auth_client.dart';
import 'package:tetes/data/secure/biometric_credential_storage.dart';

const _user = {
  'id': 'be159fad-b283-4ff1-ab73-1aa47418d755',
  'username': 'rais_uji',
  'created_at': '2026-10-19T01:00:00Z',
  'salt': 'AAECAwQFBgcICQoLDA0ODw==',
  'password_hash': 'dQOJ/dJz5Sjewgkdt1Atjz3vtuR69OMc77q26CibMso=',
  'iterations': 1000,
  'algo': 'pbkdf2-hmac-sha256',
};

AuthClient _client(MockClient mock, [_MemoryStorage? storage]) => AuthClient(
  client: mock,
  baseUrl: 'https://example.test/rest/v1',
  apiKey: 'public-test-key',
  rateLimitStorage: storage ?? _MemoryStorage(),
);

void main() {
  test('login biometrik membandingkan hash server dan membuat sesi', () async {
    final requests = <http.Request>[];
    final client = _client(
      MockClient((request) async {
        requests.add(request);
        return request.method == 'GET'
            ? http.Response(jsonEncode([_user]), 200)
            : http.Response('', 201);
      }),
    );
    final credential = await client.biometricCredential('rais_uji');
    final session = await client.loginBiometric(credential);
    expect(session.user.username, 'rais_uji');
    expect(requests.map((request) => request.method), ['GET', 'GET', 'POST']);
  });

  test('hash biometrik tidak cocok dihitung sebagai login gagal', () async {
    final secure = _MemoryStorage();
    final client = _client(
      MockClient((request) async => http.Response(jsonEncode([_user]), 200)),
      secure,
    );
    await expectLater(
      client.loginBiometric(
        const BiometricCredential(
          username: 'rais_uji',
          passwordHash: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
          salt: 'AAECAwQFBgcICQoLDA0ODw==',
          iterations: 1000,
          algo: 'pbkdf2-hmac-sha256',
        ),
      ),
      throwsA(
        isA<AuthException>().having(
          (error) => error.type,
          'type',
          AuthFailureType.invalidCredentials,
        ),
      ),
    );
    expect(secure.values.keys, contains('auth_attempts_rais_uji'));
  });
  test(
    'login membaca user dengan header dan membuat sesi tanpa mengirim password',
    () async {
      final requests = <http.Request>[];
      final storage = _MemoryStorage();
      final window =
          DateTime.now().toUtc().millisecondsSinceEpoch ~/ (15 * 60 * 1000);
      storage.values['auth_attempts_rais_uji'] = '$window:2';
      final client = _client(
        MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET') {
            return http.Response(jsonEncode([_user]), 200);
          }
          return http.Response('', 201);
        }),
        storage,
      );

      final session = await client.login(
        username: 'rais_uji',
        password: 'coffee123',
      );
      expect(session.user.username, 'rais_uji');
      expect(session.token.length, 43);
      expect(requests.map((request) => request.method), ['GET', 'POST']);
      expect(requests.first.url.path, '/rest/v1/users');
      expect(requests.first.url.queryParameters['username'], 'eq.rais_uji');
      expect(requests.first.headers['x-login-username'], 'rais_uji');
      expect(requests.first.headers['apikey'], 'public-test-key');
      expect(requests.first.headers['Authorization'], 'Bearer public-test-key');
      expect(requests.first.body, isEmpty);
      expect(requests.last.url.path, '/rest/v1/sessions');
      expect(requests.last.headers['Prefer'], 'return=minimal');
      expect(
        jsonDecode(requests.last.body),
        containsPair('user_id', _user['id']),
      );
      expect(requests.last.body, isNot(contains('coffee123')));
      expect(storage.values.containsKey('auth_attempts_rais_uji'), isFalse);
    },
  );

  test('user tidak ada dan 401 memberi pesan yang sama', () async {
    for (final response in [
      http.Response('[]', 200),
      http.Response('{}', 401),
    ]) {
      final client = _client(MockClient((_) async => response));
      await expectLater(
        client.login(username: 'rais_uji', password: 'coffee123'),
        throwsA(
          isA<AuthException>()
              .having((e) => e.type, 'type', AuthFailureType.invalidCredentials)
              .having(
                (e) => e.message,
                'message',
                'Username atau password salah',
              ),
        ),
      );
    }
  });

  test(
    'lima kegagalan disimpan lokal dan permintaan keenam dibatasi',
    () async {
      final storage = _MemoryStorage();
      var calls = 0;
      final client = _client(
        MockClient((_) async {
          calls++;
          return http.Response('{}', 401);
        }),
        storage,
      );
      for (var i = 0; i < 5; i++) {
        await expectLater(
          client.login(username: 'rais_uji', password: 'coffee123'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.type,
              'type',
              AuthFailureType.invalidCredentials,
            ),
          ),
        );
      }
      await expectLater(
        client.login(username: 'rais_uji', password: 'coffee123'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.type,
            'type',
            AuthFailureType.rateLimited,
          ),
        ),
      );
      expect(calls, 5);
      expect(storage.values.keys, contains('auth_attempts_rais_uji'));
    },
  );

  test('register mengirim dua POST dengan header username', () async {
    final requests = <http.Request>[];
    final client = _client(
      MockClient((request) async {
        requests.add(request);
        return request.url.path.endsWith('/users')
            ? http.Response(jsonEncode([_user]), 201)
            : http.Response('', 201);
      }),
    );
    await client.register(username: 'rais_uji', password: 'coffee123');
    expect(requests.length, 2);
    expect(requests.first.headers['x-login-username'], 'rais_uji');
    expect(requests.first.headers['Prefer'], 'return=representation');
    expect(requests.last.headers['Prefer'], 'return=minimal');
    expect(requests.first.body, isNot(contains('coffee123')));
  });

  test('23505 dipetakan ke usernameTaken', () async {
    final client = _client(
      MockClient((_) async => http.Response('{"code":"23505"}', 409)),
    );
    await expectLater(
      client.register(username: 'rais_uji', password: 'coffee123'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.type,
          'type',
          AuthFailureType.usernameTaken,
        ),
      ),
    );
  });

  test('akun dibuat tetapi sesi gagal mengarahkan pengguna masuk', () async {
    final client = _client(
      MockClient(
        (request) async => request.url.path.endsWith('/users')
            ? http.Response(jsonEncode([_user]), 201)
            : http.Response('{}', 500),
      ),
    );
    await expectLater(
      client.register(username: 'rais_uji', password: 'coffee123'),
      throwsA(
        isA<AuthException>()
            .having((e) => e.type, 'type', AuthFailureType.server)
            .having((e) => e.message, 'message', 'Akun dibuat. Silakan masuk.'),
      ),
    );
  });

  test('logout PATCH menerima nol baris sebagai sukses', () async {
    late http.Request request;
    final client = _client(
      MockClient((value) async {
        request = value;
        return http.Response('', 204);
      }),
    );
    await client.revokeSession(token: 'fixture-token');
    expect(request.method, 'PATCH');
    expect(request.url.path, '/rest/v1/sessions');
    expect(request.url.queryParameters['token_hash'], startsWith('eq.'));
    expect(
      request.headers['x-token-hash'],
      request.url.queryParameters['token_hash']!.substring(3),
    );
    expect(request.headers['Prefer'], 'return=minimal');
    expect(jsonDecode(request.body), {'revoked': true});
    expect(request.body, isNot(contains('fixture-token')));
  });

  test('konfigurasi kosong menghasilkan pesan jelas', () async {
    final client = AuthClient(
      client: MockClient((_) async => fail('HTTP must not run')),
    );
    await expectLater(
      client.login(username: 'rais_uji', password: 'coffee123'),
      throwsA(
        isA<AuthException>().having(
          (e) => e.message,
          'message',
          contains('Konfigurasi Supabase belum tersedia'),
        ),
      ),
    );
  });
}

class _MemoryStorage implements FlutterSecureStorage {
  final values = <String, String>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String;
    if (invocation.memberName == #read) {
      return Future<String?>.value(values[key]);
    }
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
