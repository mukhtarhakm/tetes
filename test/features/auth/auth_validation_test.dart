import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/auth/auth_validation.dart';

void main() {
  group('username', () {
    test('menerima batas dan karakter yang diizinkan', () {
      expect(AuthValidation.username('abc'), isNull);
      expect(AuthValidation.username('a.b_c123'), isNull);
      expect(AuthValidation.username('a' * 30), isNull);
    });

    test('menolak kosong, panjang salah, huruf besar, dan spasi', () {
      expect(AuthValidation.username(''), isNotNull);
      expect(AuthValidation.username('ab'), isNotNull);
      expect(AuthValidation.username('a' * 31), isNotNull);
      expect(AuthValidation.username('Rais'), isNotNull);
      expect(AuthValidation.username('rais hakim'), isNotNull);
    });
  });

  group('password', () {
    test('menerima 8 sampai 128 karakter', () {
      expect(AuthValidation.password('a' * 8), isNull);
      expect(AuthValidation.password('a' * 128), isNull);
    });

    test('menghitung karakter Unicode dan menolak di luar batas', () {
      expect(AuthValidation.password('a' * 7), isNotNull);
      expect(AuthValidation.password('a' * 129), isNotNull);
      expect(AuthValidation.password('kopi☕☕☕☕'), isNull);
    });
  });

  group('konfirmasi password', () {
    test('menerima nilai sama dan menolak kosong atau berbeda', () {
      expect(AuthValidation.confirmation('rahasia123', 'rahasia123'), isNull);
      expect(AuthValidation.confirmation('rahasia123', ''), isNotNull);
      expect(
        AuthValidation.confirmation('rahasia123', 'rahasia124'),
        isNotNull,
      );
    });
  });
}
