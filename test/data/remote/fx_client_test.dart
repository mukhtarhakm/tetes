import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tetes/data/remote/fx_client.dart';
import 'package:tetes/features/beans/fx_conversion.dart';

void main() {
  late String fixture;

  setUpAll(() async {
    fixture = await File('test/fixtures/fx/latest_usd.json').readAsString();
  });

  test('memanggil endpoint dan membaca rates IDR dari fixture asli', () async {
    late http.Request capturedRequest;
    final client = FxClient(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response(fixture, 200);
      }),
      baseUrl: 'https://example.com/v1',
    );

    final quote = await client.fetch('usd');

    expect(capturedRequest.url.path, '/v1/latest');
    expect(capturedRequest.url.queryParameters, {
      'base': 'USD',
      'symbols': 'IDR',
    });
    expect(quote.currency, 'USD');
    expect(quote.rate, 18031);
    expect(quote.date, '2026-10-16');
    expect(quote.source, FxQuoteSource.network);
  });

  test('respons bukan JSON menghasilkan galat bertipe', () async {
    final client = FxClient(
      client: MockClient((_) async => http.Response('bukan-json', 200)),
    );

    await expectLater(
      client.fetch('USD'),
      throwsA(
        isA<FxException>().having(
          (error) => error.type,
          'type',
          FxFailureType.invalidResponse,
        ),
      ),
    );
  });

  test('rates tanpa IDR menghasilkan galat bertipe', () async {
    final client = FxClient(
      client: MockClient(
        (_) async =>
            http.Response('{"date":"2026-10-16","rates":{"EUR":0.8}}', 200),
      ),
    );

    await expectLater(
      client.fetch('USD'),
      throwsA(
        isA<FxException>().having(
          (error) => error.type,
          'type',
          FxFailureType.invalidResponse,
        ),
      ),
    );
  });

  test('status selain 200 menghasilkan galat server', () async {
    final client = FxClient(
      client: MockClient((_) async => http.Response('{}', 503)),
    );

    await expectLater(
      client.fetch('EUR'),
      throwsA(
        isA<FxException>().having(
          (error) => error.type,
          'type',
          FxFailureType.server,
        ),
      ),
    );
  });
}
