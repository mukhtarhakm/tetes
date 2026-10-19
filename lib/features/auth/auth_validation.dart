abstract final class AuthValidation {
  static final RegExp _usernamePattern = RegExp(r'^[a-z0-9._]{3,30}$');

  static String? username(String value) {
    if (value.isEmpty) {
      return 'Username wajib diisi.';
    }
    if (!_usernamePattern.hasMatch(value)) {
      return 'Gunakan 3-30 huruf kecil, angka, titik, atau garis bawah.';
    }
    return null;
  }

  static String? password(String value) {
    final length = value.runes.length;
    if (value.isEmpty) {
      return 'Password wajib diisi.';
    }
    if (length < 8) {
      return 'Password minimal 8 karakter.';
    }
    if (length > 128) {
      return 'Password maksimal 128 karakter.';
    }
    return null;
  }

  static String? confirmation(String password, String confirmation) {
    if (confirmation.isEmpty) {
      return 'Konfirmasi password wajib diisi.';
    }
    if (confirmation != password) {
      return 'Konfirmasi password tidak sama.';
    }
    return null;
  }
}
