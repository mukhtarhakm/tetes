enum FxQuoteSource { network, cache, local }

class FxQuote {
  const FxQuote({
    required this.currency,
    required this.rate,
    required this.date,
    required this.source,
  });

  final String currency;
  final double rate;
  final String date;
  final FxQuoteSource source;

  FxQuote copyWith({FxQuoteSource? source}) {
    return FxQuote(
      currency: currency,
      rate: rate,
      date: date,
      source: source ?? this.source,
    );
  }
}

class FxPricingInput {
  const FxPricingInput({
    required this.priceOriginal,
    required this.currency,
    required this.packSizeG,
  });

  final double? priceOriginal;
  final String? currency;
  final double? packSizeG;

  bool get isComplete =>
      priceOriginal != null &&
      priceOriginal! > 0 &&
      currency != null &&
      packSizeG != null &&
      packSizeG! > 0;

  @override
  bool operator ==(Object other) {
    return other is FxPricingInput &&
        other.priceOriginal == priceOriginal &&
        other.currency == currency &&
        other.packSizeG == packSizeG;
  }

  @override
  int get hashCode => Object.hash(priceOriginal, currency, packSizeG);
}

abstract final class FxConversion {
  static double packagePriceIdr({
    required double priceOriginal,
    required double fxRate,
  }) {
    return priceOriginal * fxRate;
  }

  static double priceIdrPerKg({
    required double priceOriginal,
    required double fxRate,
    required double packSizeG,
  }) {
    return packagePriceIdr(priceOriginal: priceOriginal, fxRate: fxRate) /
        packSizeG *
        1000;
  }

  static bool shouldRecalculate({
    required FxPricingInput? original,
    required FxPricingInput current,
  }) {
    return original != current;
  }

  static String dateFrom(DateTime now) {
    final local = now.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }
}

class FxRequestGuard {
  int _generation = 0;
  FxPricingInput? _latestInput;

  int issue(FxPricingInput input) {
    _latestInput = input;
    return ++_generation;
  }

  void invalidate() {
    _latestInput = null;
    _generation++;
  }

  bool accepts(int generation, FxPricingInput input) {
    return generation == _generation && input == _latestInput;
  }
}
