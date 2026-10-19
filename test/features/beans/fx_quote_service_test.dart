import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/data/remote/fx_client.dart';
import 'package:tetes/features/beans/fx_conversion.dart';
import 'package:tetes/features/beans/fx_quote_service.dart';

void main() {
  test(
    'IDR memakai kurs satu dan tanggal dari sumber waktu tanpa jaringan',
    () async {
      final source = _FakeSource();
      final service = FxQuoteService(
        source: source,
        cache: _FakeCache(),
        userId: 'user-1',
        now: () => DateTime(2026, 10, 19),
      );

      final quote = await service.resolve('IDR');

      expect(quote.rate, 1);
      expect(quote.date, '2026-10-19');
      expect(quote.source, FxQuoteSource.local);
      expect(source.requestedCurrencies, isEmpty);
    },
  );

  test('hasil jaringan disimpan ke cache mata uang yang sama', () async {
    final source = _FakeSource(
      quote: const FxQuote(
        currency: 'USD',
        rate: 18031,
        date: '2026-10-16',
        source: FxQuoteSource.network,
      ),
    );
    final cache = _FakeCache();
    final service = FxQuoteService(
      source: source,
      cache: cache,
      userId: 'user-1',
    );

    final quote = await service.resolve('USD');

    expect(quote.source, FxQuoteSource.network);
    expect(cache.values['USD']?.rate, 18031);
  });

  test(
    'kegagalan jaringan hanya memakai cache mata uang yang diminta',
    () async {
      final source = _FakeSource(fails: true);
      final cache = _FakeCache()
        ..values['EUR'] = const FxQuote(
          currency: 'EUR',
          rate: 19000,
          date: '2026-10-15',
          source: FxQuoteSource.cache,
        );
      final service = FxQuoteService(
        source: source,
        cache: cache,
        userId: 'user-1',
      );

      final quote = await service.resolve('EUR');

      expect(quote.currency, 'EUR');
      expect(quote.source, FxQuoteSource.cache);
      await expectLater(
        service.resolve('USD'),
        throwsA(isA<FxQuoteException>()),
      );
    },
  );
}

class _FakeSource implements FxRateSource {
  _FakeSource({this.quote, this.fails = false});

  final FxQuote? quote;
  final bool fails;
  final List<String> requestedCurrencies = [];

  @override
  Future<FxQuote> fetch(String currency) async {
    requestedCurrencies.add(currency);
    if (fails) {
      throw const FxException(type: FxFailureType.network, message: 'offline');
    }
    return quote!;
  }
}

class _FakeCache implements FxCacheStore {
  final Map<String, FxQuote> values = {};

  @override
  Future<FxQuote?> readFxCache({
    required String userId,
    required String currency,
  }) async {
    return values[currency];
  }

  @override
  Future<void> writeFxCache({
    required String userId,
    required FxQuote quote,
  }) async {
    values[quote.currency] = quote;
  }
}
