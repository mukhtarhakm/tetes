import '../../data/remote/fx_client.dart';
import 'fx_conversion.dart';

abstract interface class FxCacheStore {
  Future<FxQuote?> readFxCache({
    required String userId,
    required String currency,
  });

  Future<void> writeFxCache({required String userId, required FxQuote quote});
}

class FxQuoteException implements Exception {
  const FxQuoteException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FxQuoteService {
  FxQuoteService({
    required this.source,
    required this.cache,
    required this.userId,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final FxRateSource source;
  final FxCacheStore cache;
  final String userId;
  final DateTime Function() _now;

  Future<FxQuote> resolve(String currency) async {
    final normalizedCurrency = currency.toUpperCase();
    if (normalizedCurrency == 'IDR') {
      return FxQuote(
        currency: normalizedCurrency,
        rate: 1,
        date: FxConversion.dateFrom(_now()),
        source: FxQuoteSource.local,
      );
    }

    try {
      final quote = await source.fetch(normalizedCurrency);
      await cache.writeFxCache(userId: userId, quote: quote);
      return quote;
    } on FxException {
      final cached = await cache.readFxCache(
        userId: userId,
        currency: normalizedCurrency,
      );
      if (cached != null) {
        return cached.copyWith(source: FxQuoteSource.cache);
      }
      throw const FxQuoteException(_unavailableMessage);
    }
  }

  static const _unavailableMessage =
      'Kurs belum tersedia. Biji tetap dapat disimpan tanpa harga rupiah.';
}
