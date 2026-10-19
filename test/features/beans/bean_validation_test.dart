import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/beans/bean_validation.dart';

void main() {
  test('data wajib minimal diterima', () {
    final errors = BeanValidation.validate(
      name: 'Gayo Natural',
      species: BeanSpecies.arabika,
      stockText: '0',
      priceText: '',
      currency: null,
      arabicaPercent: null,
    );

    expect(errors, isEmpty);
  });

  test('nama dan spesies wajib diisi', () {
    final errors = BeanValidation.validate(
      name: '  ',
      species: null,
      stockText: '100',
      priceText: '',
      currency: null,
      arabicaPercent: null,
    );

    expect(errors, containsPair('name', 'Nama biji wajib diisi.'));
    expect(errors, containsPair('species', 'Pilih spesies biji.'));
  });

  test('harga dan stok negatif ditolak', () {
    final errors = BeanValidation.validate(
      name: 'Biji Uji',
      species: BeanSpecies.robusta,
      stockText: '-1',
      priceText: '-1000',
      currency: 'IDR',
      arabicaPercent: null,
    );

    expect(errors['stock'], 'Stok tidak boleh negatif.');
    expect(errors['price'], 'Harga tidak boleh negatif.');
  });

  test('harga yang diisi memerlukan mata uang', () {
    final errors = BeanValidation.validate(
      name: 'Biji Uji',
      species: BeanSpecies.arabika,
      stockText: '100',
      priceText: '10',
      currency: null,
      arabicaPercent: null,
    );

    expect(errors['currency'], 'Pilih mata uang untuk harga.');
  });

  test('persen arabika wajib 0 sampai 100 hanya untuk campuran', () {
    final missing = BeanValidation.validate(
      name: 'Campuran',
      species: BeanSpecies.campuran,
      stockText: '100',
      priceText: '',
      currency: null,
      arabicaPercent: null,
    );
    final tooHigh = BeanValidation.validate(
      name: 'Campuran',
      species: BeanSpecies.campuran,
      stockText: '100',
      priceText: '',
      currency: null,
      arabicaPercent: 101,
    );
    final wrongSpecies = BeanValidation.validate(
      name: 'Arabika',
      species: BeanSpecies.arabika,
      stockText: '100',
      priceText: '',
      currency: null,
      arabicaPercent: 70,
    );

    expect(missing, contains('arabicaPercent'));
    expect(tooHigh, contains('arabicaPercent'));
    expect(wrongSpecies, contains('arabicaPercent'));
  });
}
