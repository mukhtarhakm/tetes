import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/explore/currency_calculator.dart';

void main() {
  test('angka ribuan dan desimal koma atau titik', () {
    expect(CurrencyCalculator.parseAmount('1.250,50'), 1250.5);
    expect(CurrencyCalculator.parseAmount('1,250.50'), 1250.5);
    expect(CurrencyCalculator.parseAmount('12,5'), 12.5);
    expect(CurrencyCalculator.parseAmount('12.5'), 12.5);
    expect(CurrencyCalculator.parseAmount('1.000'), 1000);
    for (final invalid in ['', '0', '-1', 'abc', '1,2,3']) {
      expect(CurrencyCalculator.parseAmount(invalid), isNull);
    }
  });

  test('konversi mata uang asing melalui rupiah', () {
    expect(CurrencyCalculator.convertViaIdr(amount: 2,
      fromIdrRate: 16000, toIdrRate: 20000), 1.6);
    expect(() => CurrencyCalculator.convertViaIdr(amount: 0,
      fromIdrRate: 16000, toIdrRate: 20000), throwsArgumentError);
  });
}
