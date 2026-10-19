import 'bean_model.dart';

abstract final class BeanValidation {
  static const maximumTagCount = 10;
  static const maximumCustomTagLength = 30;
  static const maximumCustomProcessLength = 40;

  static Map<String, String> validate({
    required String name,
    required BeanSpecies? species,
    required String stockText,
    required String priceText,
    required String packSizeText,
    required bool customPackSelected,
    required String? currency,
    required int? arabicaPercent,
    required BeanProcess? process,
    required String processCustom,
    required Iterable<String> tags,
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
    } else if (stock <= 0) {
      errors['stock'] = 'Stok harus lebih dari 0 gram.';
    }

    final normalizedPrice = priceText.trim().replaceAll(',', '.');
    final normalizedPackSize = packSizeText.trim().replaceAll(',', '.');
    final hasPrice = normalizedPrice.isNotEmpty;
    final hasPackSize = normalizedPackSize.isNotEmpty;
    if (normalizedPrice.isNotEmpty) {
      final price = double.tryParse(normalizedPrice);
      if (price == null) {
        errors['price'] = 'Harga harus berupa angka.';
      } else if (price <= 0) {
        errors['price'] = 'Harga harus lebih dari 0.';
      }
      if (currency == null) {
        errors['currency'] = 'Pilih mata uang untuk harga.';
      }
    }

    if (hasPackSize) {
      final packSize = double.tryParse(normalizedPackSize);
      if (packSize == null) {
        errors['packSize'] = 'Ukuran kemasan harus berupa angka.';
      } else if (packSize <= 0) {
        errors['packSize'] = 'Ukuran kemasan harus lebih dari 0 gram.';
      }
    } else if (hasPrice || customPackSelected) {
      errors['packSize'] = 'Ukuran kemasan wajib diisi.';
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

    final normalizedProcessCustom = processCustom.trim();
    if (process == BeanProcess.lainnya) {
      if (normalizedProcessCustom.isEmpty) {
        errors['processCustom'] = 'Isi nama proses lainnya.';
      } else if (normalizedProcessCustom.length > maximumCustomProcessLength) {
        errors['processCustom'] =
            'Nama proses maksimal $maximumCustomProcessLength karakter.';
      }
    }

    final normalizedTags = tags.map(normalizeTag).toList();
    if (normalizedTags.length > maximumTagCount) {
      errors['tags'] = 'Maksimal $maximumTagCount tag per biji.';
    } else if (normalizedTags.toSet().length != normalizedTags.length) {
      errors['tags'] = 'Tag tidak boleh kembar.';
    } else {
      for (final tag in normalizedTags) {
        if (!RoasteryNoteTag.isBuiltIn(tag) &&
            tag.length > maximumCustomTagLength) {
          errors['tags'] =
              'Tag buatan sendiri maksimal $maximumCustomTagLength karakter.';
          break;
        }
      }
    }

    return errors;
  }

  static String? validateCustomTag(
    String value, {
    required Iterable<String> existingTags,
  }) {
    final normalized = normalizeTag(value);
    if (normalized.isEmpty) {
      return 'Tag wajib diisi.';
    }
    if (normalized.contains(',')) {
      return 'Tag tidak boleh mengandung koma.';
    }
    if (normalized.length > maximumCustomTagLength) {
      return 'Tag maksimal $maximumCustomTagLength karakter.';
    }
    if (existingTags.map(normalizeTag).contains(normalized)) {
      return 'Tag sudah digunakan.';
    }
    if (existingTags.length >= maximumTagCount) {
      return 'Maksimal $maximumTagCount tag per biji.';
    }
    return null;
  }

  static String normalizeTag(String value) => value.trim().toLowerCase();

  static double parseNumber(String value) {
    return double.parse(value.trim().replaceAll(',', '.'));
  }
}
