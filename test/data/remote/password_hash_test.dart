import 'package:cryptography/cryptography.dart' as cryptography;
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/data/remote/password_hash.dart';

void main() {
  // Values generated with Node.js crypto.pbkdf2Sync(..., 'sha256').
  final vectors = [
    (
      'coffee123',
      '000102030405060708090a0b0c0d0e0f',
      '750389fdd273e528dec2091db7502d8f3defb6e47af4e31cefbab6e8289b32ca',
    ),
    (
      'kopi☕水ABC',
      '101112131415161718191a1b1c1d1e1f',
      '6c02bf8a43f977c109791dde3a745b762e98d0f04a9e2d8eb22be0154c45f0ae',
    ),
    (
      'a' * 128,
      '202122232425262728292a2b2c2d2e2f',
      '2687e317324463ebb78697125b7a5609a8c448f814e56f1796334a828b64f3ca',
    ),
  ];

  for (final vector in vectors) {
    for (final fallback in [false, true]) {
      test(
        'PBKDF2 ${fallback ? 'fallback' : 'utama'} cocok dengan Node.js untuk vektor ${vectors.indexOf(vector) + 1}',
        () async {
          final salt = _hexBytes(vector.$2);
          final result = await derivePasswordHash(
            vector.$1,
            salt,
            1000,
            forceFallback: fallback,
            algorithmOverride: fallback
                ? null
                : cryptography.Pbkdf2.hmacSha256(iterations: 1000, bits: 256),
          );
          expect(_hex(result), vector.$3);
        },
      );
    }
  }

  for (final fallback in [false, true]) {
    test(
      'PBKDF2 600000 iterasi ${fallback ? 'fallback' : 'utama'} cocok dengan Node.js',
      () async {
        final result = await derivePasswordHash(
          'coffee123',
          _hexBytes('000102030405060708090a0b0c0d0e0f'),
          600000,
          forceFallback: fallback,
          algorithmOverride: fallback
              ? null
              : cryptography.Pbkdf2.hmacSha256(iterations: 600000, bits: 256),
        );
        expect(
          _hex(result),
          'b18e412961448d720fca1b52e09322b42560503376becdb3571d280a701f2c06',
        );
      },
    );
  }

  test('galat implementasi utama memakai fallback', () async {
    final result = await derivePasswordHash(
      vectors.first.$1,
      _hexBytes(vectors.first.$2),
      1000,
      algorithmOverride: _FailingPbkdf2(),
    );
    expect(_hex(result), vectors.first.$3);
  });

  test('perbandingan tetap menolak panjang dan nilai berbeda', () {
    expect(constantTimeEquals([1, 2], [1, 2]), isTrue);
    expect(constantTimeEquals([1, 2], [1, 3]), isFalse);
    expect(constantTimeEquals([1, 2], [1]), isFalse);
  });
}

List<int> _hexBytes(String value) => [
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
];

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

class _FailingPbkdf2 implements cryptography.Pbkdf2 {
  @override
  Future<cryptography.SecretKey> deriveKeyFromPassword({
    required String password,
    required List<int> nonce,
  }) async => throw StateError('Native unavailable');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
