import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tetes/data/remote/chain_verifier.dart';

final key = '0x${List.filled(64, 'a').join()}';
final hash = List.filled(64, 'b').join();

String word(int value) => value.toRadixString(16).padLeft(64, '0');

void main() {
  Future<ChainVerification> verify(String result, String localHash) async {
    final verifier = ChainVerifier(
      rpcUrl: 'https://example.invalid',
      client: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['method'], 'eth_call');
        expect((body['params'] as List).first['data'],
          '${ChainVerifier.latestSelector}${key.substring(2)}');
        return http.Response(jsonEncode({'jsonrpc': '2.0', 'id': 1,
          'result': result}), 200);
      }),
    );
    return verifier.verify(key, localHash);
  }

  test('selector dan tiga kata ABI', () async {
    expect(ChainVerifier.latestSelector.length, 10);
    final result = await verify('0x$hash${word(7)}${word(1729728000)}', hash);
    expect(result, isA<Match>());
    expect((result as Match).seq, 7);
    expect(result.anchoredAt.isUtc, isTrue);
  });

  test('Mismatch, NotFound, dan Unreachable', () async {
    final data = '0x$hash${word(2)}${word(1729728000)}';
    final mismatch = await verify(data, List.filled(64, 'c').join());
    expect(mismatch, isA<Mismatch>());
    expect((mismatch as Mismatch).onChainSeq, 2);
    expect(await verify('0x${List.filled(192, '0').join()}', hash),
      isA<NotFound>());
    expect(await verify('0x1234', hash), isA<Unreachable>());
  });

  test('seq on-chain lebih baru tanpa seduhan lokal menghasilkan Unknown', () {
    final verifier = ChainVerifier(client: MockClient((_) async => http.Response('', 500)));
    final head = ChainHead(hash, 5, DateTime.utc(2026, 10, 24));
    final result = verifier.compareAtSeq(head, null);
    expect(result, isA<Unknown>());
    expect((result as Unknown).message,
      'Jangkar di rantai lebih baru dari data di perangkat ini');
  });

  test('seq sama dengan hash berbeda menghasilkan Mismatch', () {
    final verifier = ChainVerifier(client: MockClient((_) async => http.Response('', 500)));
    final head = ChainHead(hash, 5, DateTime.utc(2026, 10, 24));
    expect(verifier.compareAtSeq(head, List.filled(64, 'c').join()), isA<Mismatch>());
  });
}
