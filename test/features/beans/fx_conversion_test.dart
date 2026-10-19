import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/beans/fx_conversion.dart';

void main() {
  test('menghitung harga rupiah per kemasan dan per kg', () {
    final packagePrice = FxConversion.packagePriceIdr(
      priceOriginal: 10,
      fxRate: 18031,
    );
    final perKg = FxConversion.priceIdrPerKg(
      priceOriginal: 10,
      fxRate: 18031,
      packSizeG: 250,
    );

    expect(packagePrice, 180310);
    expect(perKg, 721240);
  });

  test('IDR memakai kurs satu', () {
    expect(
      FxConversion.priceIdrPerKg(
        priceOriginal: 100000,
        fxRate: 1,
        packSizeG: 250,
      ),
      400000,
    );
  });

  test('tidak menghitung ulang bila tiga input tidak berubah', () {
    const original = FxPricingInput(
      priceOriginal: 10,
      currency: 'USD',
      packSizeG: 250,
    );

    expect(
      FxConversion.shouldRecalculate(original: original, current: original),
      isFalse,
    );
    expect(
      FxConversion.shouldRecalculate(
        original: original,
        current: const FxPricingInput(
          priceOriginal: 11,
          currency: 'USD',
          packSizeG: 250,
        ),
      ),
      isTrue,
    );
  });

  test('penjaga menolak respons untuk input yang sudah usang', () {
    final guard = FxRequestGuard();
    const oldInput = FxPricingInput(
      priceOriginal: 10,
      currency: 'USD',
      packSizeG: 250,
    );
    const latestInput = FxPricingInput(
      priceOriginal: 12,
      currency: 'EUR',
      packSizeG: 200,
    );

    final oldRequest = guard.issue(oldInput);
    final latestRequest = guard.issue(latestInput);

    expect(guard.accepts(oldRequest, oldInput), isFalse);
    expect(guard.accepts(latestRequest, latestInput), isTrue);
  });
}
