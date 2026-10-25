import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/brew/custom_taste_tags.dart';

void main() {
  test('normalisasi merapikan spasi, huruf, dan duplikat', () {
    expect(normalizeCustomTasteTags([' Teh   Hitam ', 'teh hitam', 'Jeruk-2']),
      ['teh hitam', 'jeruk-2']);
    expect(normalizeCustomTasteTags(['Kréma']), ['kréma']);
  });

  test('menolak kosong, terlalu panjang, karakter terlarang, bawaan, dan lebih dari tiga', () {
    for (final tags in [
      ['   '], ['abcdefghijklmnopqrstu'], ['teh!'], ['MANIS'],
      ['satu', 'dua', 'tiga', 'empat'],
    ]) {
      expect(() => normalizeCustomTasteTags(tags), throwsFormatException);
    }
  });
}
