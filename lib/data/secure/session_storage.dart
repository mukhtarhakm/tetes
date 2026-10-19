import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorageException implements Exception {
  const SessionStorageException();
}

class StoredSession {
  const StoredSession({
    required this.token,
    required this.userId,
    required this.expiresAt,
  });

  final String token;
  final String userId;
  final String expiresAt;
}

abstract interface class SessionStorage {
  Future<void> saveSession({
    required String token,
    required String userId,
    required String expiresAt,
  });

  Future<StoredSession?> readSession();

  Future<void> clearSession();

  Future<List<String>> readPendingRevokeTokens();

  Future<void> writePendingRevokeTokens(List<String> tokens);
}

class SecureSessionStorage implements SessionStorage {
  const SecureSessionStorage(this._storage);

  static const _tokenKey = 'session_token';
  static const _userIdKey = 'user_id';
  static const _expiresAtKey = 'expires_at';
  static const _pendingRevokeTokenKey = 'pending_revoke_token';

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

  @override
  Future<StoredSession?> readSession() async {
    try {
      final values = await Future.wait([
        _storage.read(key: _tokenKey),
        _storage.read(key: _userIdKey),
        _storage.read(key: _expiresAtKey),
      ]);
      final token = values[0];
      final userId = values[1];
      final expiresAt = values[2];

      if (token == null && userId == null && expiresAt == null) {
        return null;
      }
      if (token == null || userId == null || expiresAt == null) {
        await clearSession();
        return null;
      }

      return StoredSession(token: token, userId: userId, expiresAt: expiresAt);
    } catch (_) {
      throw const SessionStorageException();
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      await Future.wait([
        _storage.delete(key: _tokenKey),
        _storage.delete(key: _userIdKey),
        _storage.delete(key: _expiresAtKey),
      ]);
    } catch (_) {
      throw const SessionStorageException();
    }
  }

  @override
  Future<List<String>> readPendingRevokeTokens() async {
    try {
      final value = await _storage.read(key: _pendingRevokeTokenKey);
      if (value == null) {
        return const [];
      }

      final decoded = jsonDecode(value);
      if (decoded is! List ||
          decoded.any((token) => token is! String || token.isEmpty)) {
        throw const FormatException();
      }
      return List<String>.unmodifiable(decoded.cast<String>());
    } catch (_) {
      throw const SessionStorageException();
    }
  }

  @override
  Future<void> writePendingRevokeTokens(List<String> tokens) async {
    try {
      if (tokens.isEmpty) {
        await _storage.delete(key: _pendingRevokeTokenKey);
        return;
      }
      await _storage.write(
        key: _pendingRevokeTokenKey,
        value: jsonEncode(tokens),
      );
    } catch (_) {
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
