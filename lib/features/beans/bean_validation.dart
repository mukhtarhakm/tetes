import 'bean_model.dart';

abstract final class BeanValidation {
  static Map<String, String> validate({
    required String name,
    required BeanSpecies? species,
    required String stockText,
    required String priceText,
    required String? currency,
    required int? arabicaPercent,
  }) {
    final errors = <String, String>{};

    if (name.trim().isEmpty) {
      errors['name'] = 'Nama biji wajib diisi.';
    }
    if (species == null) {
      errors['species'] = 'Pilih spesies biji.';
    }

    final stock = double.tryParse(stockText.trim().replaceAll(',', '.'));
    if (stock == null) {
      errors['stock'] = 'Stok harus berupa angka.';
    } else if (stock < 0) {
      errors['stock'] = 'Stok tidak boleh negatif.';
    }

    final normalizedPrice = priceText.trim().replaceAll(',', '.');
    if (normalizedPrice.isNotEmpty) {
      final price = double.tryParse(normalizedPrice);
      if (price == null) {
        errors['price'] = 'Harga harus berupa angka.';
      } else if (price < 0) {
        errors['price'] = 'Harga tidak boleh negatif.';
      }
      if (currency == null) {
        errors['currency'] = 'Pilih mata uang untuk harga.';
      }
    }

    if (species == BeanSpecies.campuran) {
      if (arabicaPercent == null ||
          arabicaPercent < 0 ||
          arabicaPercent > 100) {
        errors['arabicaPercent'] = 'Persen arabika harus 0 sampai 100.';
      }
    } else if (arabicaPercent != null) {
      errors['arabicaPercent'] = 'Persen arabika hanya untuk spesies campuran.';
    }

    return errors;
  }

  static double parseNumber(String value) {
    return double.parse(value.trim().replaceAll(',', '.'));
  }
}
