import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorageException implements Exception {
  const SessionStorageException();
}

abstract interface class SessionStorage {
  Future<void> saveSession({
    required String token,
    required String userId,
    required String expiresAt,
  });
}

class SecureSessionStorage implements SessionStorage {
  const SecureSessionStorage(this._storage);

  static const _tokenKey = 'session_token';
  static const _userIdKey = 'user_id';
  static const _expiresAtKey = 'expires_at';

  final FlutterSecureStorage _storage;

  @override
  Future<void> saveSession({
    required String token,
    required String userId,
    required String expiresAt,
  }) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _userIdKey, value: userId);
      await _storage.write(key: _expiresAtKey, value: expiresAt);
    } catch (_) {
      await _removePartialSession();
      throw const SessionStorageException();
    }
  }

  Future<void> _removePartialSession() async {
    for (final key in const [_tokenKey, _userIdKey, _expiresAtKey]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {
        // Penghapusan terbaik-usaha; kegagalan awal tetap dilaporkan ke pemanggil.
      }
    }
  }
}
