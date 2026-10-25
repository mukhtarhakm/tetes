import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricCredential {
  const BiometricCredential({
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.iterations,
    required this.algo,
  });

  final String username;
  final String passwordHash;
  final String salt;
  final int iterations;
  final String algo;
}

class BiometricCredentialStorage {
  const BiometricCredentialStorage(this._storage);

  final FlutterSecureStorage _storage;

  String _key(String username) => 'biometric_credential_$username';

  Future<void> save(BiometricCredential credential) => _storage.write(
    key: _key(credential.username),
    value: jsonEncode({
      'username': credential.username,
      'password_hash': credential.passwordHash,
      'salt': credential.salt,
      'iterations': credential.iterations,
      'algo': credential.algo,
    }),
  );

  Future<BiometricCredential?> read(String username) async {
    final value = await _storage.read(key: _key(username));
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map ||
        decoded['username'] != username ||
        decoded['password_hash'] is! String ||
        decoded['salt'] is! String ||
        decoded['iterations'] is! int ||
        decoded['algo'] is! String) {
      throw const FormatException('Kredensial biometrik tidak valid.');
    }
    return BiometricCredential(
      username: username,
      passwordHash: decoded['password_hash'] as String,
      salt: decoded['salt'] as String,
      iterations: decoded['iterations'] as int,
      algo: decoded['algo'] as String,
    );
  }

  Future<void> delete(String username) => _storage.delete(key: _key(username));
}
