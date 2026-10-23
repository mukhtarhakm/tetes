import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/beans/bean_validation.dart';

void main() {
  test('data wajib minimal diterima', () {
    final errors = _validate();

    expect(errors, isEmpty);
  });

  test('nama dan spesies wajib diisi', () {
    final errors = _validate(name: '  ', species: null);

    expect(errors, containsPair('name', 'Nama biji wajib diisi.'));
    expect(errors, containsPair('species', 'Pilih spesies biji.'));
  });

  test('stok nol diterima; stok negatif, harga, dan kemasan ditolak', () {
    final errors = _validate(
      stockText: '0',
      priceText: '-1000',
      packSizeText: '0',
      currency: 'IDR',
    );

    expect(errors['stock'], isNull);
    expect(_validate(stockText: '-1')['stock'], 'Stok tidak boleh negatif.');
    expect(errors['price'], 'Harga harus lebih dari 0.');
    expect(errors['packSize'], 'Ukuran kemasan harus lebih dari 0 gram.');
  });

  test('harga yang diisi memerlukan mata uang dan ukuran kemasan', () {
    final errors = _validate(priceText: '10000');

    expect(errors['currency'], 'Pilih mata uang untuk harga.');
    expect(errors['packSize'], 'Ukuran kemasan wajib diisi.');
  });

  test('biji lama dengan harga wajib mengisi kemasan saat disimpan ulang', () {
    final errors = _validate(priceText: '75000', currency: 'IDR');

    expect(errors, contains('packSize'));
  });

  test('persen arabika wajib 0 sampai 100 hanya untuk campuran', () {
    final missing = _validate(
      species: BeanSpecies.campuran,
      arabicaPercent: null,
    );
    final tooHigh = _validate(
      species: BeanSpecies.campuran,
      arabicaPercent: 101,
    );
    final wrongSpecies = _validate(arabicaPercent: 70);

    expect(missing, contains('arabicaPercent'));
    expect(tooHigh, contains('arabicaPercent'));
    expect(wrongSpecies, contains('arabicaPercent'));
  });

  test('proses lainnya wajib diisi dan maksimal 40 karakter', () {
    final missing = _validate(process: BeanProcess.lainnya);
    final tooLong = _validate(
      process: BeanProcess.lainnya,
      processCustom: 'a' * 41,
    );
    final valid = _validate(
      process: BeanProcess.lainnya,
      processCustom: 'anaerobik',
    );

    expect(missing, contains('processCustom'));
    expect(tooLong, contains('processCustom'));
    expect(valid, isNot(contains('processCustom')));
  });

  test('tag sendiri dinormalisasi dan menolak koma serta duplikat', () {
    expect(BeanValidation.normalizeTag('  Beri Merah  '), 'beri merah');
    expect(
      BeanValidation.validateCustomTag('asam,manis', existingTags: const []),
      'Tag tidak boleh mengandung koma.',
    );
    expect(
      BeanValidation.validateCustomTag(
        ' MANIS ',
        existingTags: const ['manis'],
      ),
      'Tag sudah digunakan.',
    );
  });

  test('batas sepuluh tag menghitung tag bawaan dan tag sendiri', () {
    final tags = [
      ...RoasteryNoteTag.values.take(9).map((tag) => tag.databaseValue),
      'tag sendiri',
    ];

    expect(
      BeanValidation.validateCustomTag('tambahan', existingTags: tags),
      'Maksimal 10 tag per biji.',
    );
    expect(_validate(tags: [...tags, 'kelebihan']), contains('tags'));
  });
}

Map<String, String> _validate({
  String name = 'Gayo Natural',
  BeanSpecies? species = BeanSpecies.arabika,
  String stockText = '100',
  String priceText = '',
  String packSizeText = '',
  bool customPackSelected = false,
  String? currency,
  int? arabicaPercent,
  BeanProcess? process,
  String processCustom = '',
  Iterable<String> tags = const [],
}) {
  return BeanValidation.validate(
    name: name,
    species: species,
    stockText: stockText,
    priceText: priceText,
    packSizeText: packSizeText,
    customPackSelected: customPackSelected,
    currency: currency,
    arabicaPercent: arabicaPercent,
    process: process,
    processCustom: processCustom,
    tags: tags,
  );
}
