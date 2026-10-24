import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tetes/data/remote/anchor_client.dart';
import 'package:tetes/data/secure/session_storage.dart';

class _Storage implements SessionStorage {
  @override
  Future<StoredSession?> readSession() async => const StoredSession(
    token: 'test-token', userId: 'user-1', expiresAt: '2026-10-24T00:00:00Z');
  @override
  Future<void> clearSession() async {}
  @override
  Future<List<String>> readPendingRevokeTokens() async => [];
  @override
  Future<void> saveSession({required String token, required String userId, required String expiresAt}) async {}
  @override
  Future<void> writePendingRevokeTokens(List<String> tokens) async {}
}

void main() {
  Future<AnchorResult> request(int status, Map<String, Object?> body,
      {Map<String, String> headers = const {}}) async {
    final client = AnchorClient(
      sessionStorage: _Storage(), baseUrl: 'https://example.invalid/functions',
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/functions/anchor');
        expect(request.headers['x-session-token'], 'test-token');
        expect(jsonDecode(request.body), {});
        return http.Response(jsonEncode(body), status, headers: headers);
      }),
    );
    return client.requestAnchor('user-1');
  }

  test('confirmed dan already_anchored sama-sama sukses', () async {
    final confirmed = await request(200, {
      'anchored': true, 'seq': 2, 'head_hash': List.filled(64, 'a').join(),
      'user_key': '0x${List.filled(64, 'b').join()}',
      'tx_hash': '0x${List.filled(64, 'c').join()}',
      'explorer_url': 'https://example.invalid/tx',
    });
    expect(confirmed, isA<Confirmed>());
    expect((confirmed as Confirmed).seq, 2);
    final already = await request(200, {
      'anchored': false, 'reason': 'already_anchored', 'seq': 2, 'tx_hash': null,
    });
    expect(already, isA<Confirmed>());
    expect((already as Confirmed).alreadyAnchored, isTrue);
  });

  test('no_brews, pending, 429, 401, dan galat', () async {
    expect(await request(200, {'anchored': false, 'reason': 'no_brews'}),
      isA<NothingToAnchor>());
    final pending = await request(202, {
      'anchored': false, 'reason': 'pending', 'seq': 3, 'tx_hash': null,
    });
    expect((pending as Pending).seq, 3);
    final limited = await request(429, {'error': {}}, headers: {'Retry-After': '45'});
    expect((limited as RateLimited).retryAfter.inSeconds, 45);
    expect(await request(401, {'error': {}}), isA<Unauthorized>());
    expect(await request(503, {'error': {'message': 'Coba lagi nanti.'}}),
      isA<Failed>());
  });
}
