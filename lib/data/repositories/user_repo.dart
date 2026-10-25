import 'package:sqflite/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../remote/auth_client.dart';
import '../secure/biometric_credential_storage.dart';
import '../secure/session_storage.dart';

class UserRepository {
  const UserRepository(
    this._database,
    this._authClient,
    this._sessionStorage, [
    this._biometricStorage = const BiometricCredentialStorage(
      FlutterSecureStorage(),
    ),
  ]);

  final Database _database;
  final AuthClient _authClient;
  final SessionStorage _sessionStorage;
  final BiometricCredentialStorage _biometricStorage;

  static const _biometricEnabledKey = 'biometric_enabled';
  static const _biometricPromptedKey = 'biometric_prompted';

  Future<String> register({
    required String username,
    required String password,
  }) async {
    final session = await _authClient.register(
      username: username,
      password: password,
    );
    await _persistAuthentication(session);
    return session.user.id;
  }

  Future<String> login({
    required String username,
    required String password,
  }) async {
    final session = await _authClient.login(
      username: username,
      password: password,
    );
    await _persistAuthentication(session);
    return session.user.id;
  }

  Future<String> loginBiometric(String username) async {
    final userId = await _userIdForUsername(username);
    if (userId == null || !await isBiometricEnabled(userId)) {
      throw const AuthException(
        type: AuthFailureType.invalidCredentials,
        message: 'Masuk dengan password, lalu aktifkan lagi sidik jari',
      );
    }
    BiometricCredential? credential;
    try {
      credential = await _biometricStorage.read(username);
    } catch (_) {
      await _clearInvalidBiometric(userId);
      throw const AuthException(
        type: AuthFailureType.localStorage,
        message: 'Masuk dengan password, lalu aktifkan lagi sidik jari',
      );
    }
    if (credential == null) {
      await _clearInvalidBiometric(userId);
      throw const AuthException(
        type: AuthFailureType.invalidCredentials,
        message: 'Masuk dengan password, lalu aktifkan lagi sidik jari',
      );
    }
    try {
      final session = await _authClient.loginBiometric(credential,
          expectedUserId: userId);
      await _persistAuthentication(session);
      return userId;
    } on AuthException catch (error) {
      if (error.type != AuthFailureType.invalidCredentials) rethrow;
      await _clearInvalidBiometric(userId);
      throw const AuthException(
        type: AuthFailureType.invalidCredentials,
        message: 'Masuk dengan password, lalu aktifkan lagi sidik jari',
      );
    }
  }

  Future<String?> availableBiometricUsername([String? username]) async {
    final rows = await _database.rawQuery(
      '''
      SELECT users.id, users.username FROM users
      JOIN settings ON settings.user_id = users.id
      WHERE settings.key = ? AND settings.value = '1'
        ${username == null || username.isEmpty ? '' : 'AND users.username = ?'}
      ORDER BY users.last_login_at DESC
    ''',
      [
        _biometricEnabledKey,
        if (username != null && username.isNotEmpty) username,
      ],
    );
    for (final row in rows) {
      final candidate = row['username'] as String;
      try {
        if (await _biometricStorage.read(candidate) != null) return candidate;
      } catch (_) {
        await _clearInvalidBiometric(row['id'] as String);
      }
    }
    return null;
  }

  Future<void> _clearInvalidBiometric(String userId) async {
    try {
      await disableBiometric(userId);
    } catch (_) {
      // The flag is disabled even if the invalid Keystore entry cannot be deleted.
    }
  }

  Future<String?> _userIdForUsername(String username) async {
    final rows = await _database.query(
      'users',
      columns: ['id'],
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['id'] as String;
  }

  Future<int> countPendingSyncData(String userId) async {
    final rows = await _database.rawQuery('''
      SELECT SUM(pending_count) AS total
      FROM (
        SELECT COUNT(*) AS pending_count FROM beans
          WHERE user_id = ? AND sync_status = 'pending'
        UNION ALL
        SELECT COUNT(*) FROM brews
          WHERE user_id = ? AND sync_status = 'pending'
        UNION ALL
        SELECT COUNT(*) FROM events
          WHERE user_id = ? AND sync_status = 'pending'
        UNION ALL
        SELECT COUNT(*) FROM game_scores
          WHERE user_id = ? AND sync_status = 'pending'
        UNION ALL
        SELECT COUNT(*) FROM feedback
          WHERE user_id = ? AND sync_status = 'pending'
      )
      ''', List.filled(5, userId));
    return (rows.single['total'] as num?)?.toInt() ?? 0;
  }

  Future<bool> isBiometricEnabled(String userId) {
    return _isSettingEnabled(userId, _biometricEnabledKey);
  }

  Future<Map<String, Object?>?> profile(String userId) async {
    final rows = await _database.query(
      'users',
      columns: ['id', 'username', 'photo_path', 'created_at'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }

  Future<void> savePhotoPath(String userId, String fileName) async {
    final changed = await _database.update(
      'users',
      {'photo_path': fileName},
      where: 'id = ?',
      whereArgs: [userId],
    );
    if (changed != 1) throw StateError('Profil pengguna tidak tersedia.');
  }

  Future<void> disableBiometric(String userId) async {
    final profile = await this.profile(userId);
    final username = profile?['username'] as String?;
    try {
      if (username != null) await _biometricStorage.delete(username);
    } finally {
      await _upsertSetting(
        _database,
        userId: userId,
        key: _biometricEnabledKey,
        value: '0',
      );
    }
  }

  Future<bool> wasBiometricPrompted(String userId) {
    return _isSettingEnabled(userId, _biometricPromptedKey);
  }

  Future<void> enableBiometric(String userId) async {
    final profile = await this.profile(userId);
    final username = profile?['username'] as String?;
    if (username == null) throw StateError('Profil pengguna tidak tersedia.');
    final credential = await _authClient.biometricCredential(username);
    await _biometricStorage.save(credential);
    await _database.transaction((transaction) async {
      await _upsertSetting(
        transaction,
        userId: userId,
        key: _biometricEnabledKey,
        value: '1',
      );
      await _upsertSetting(
        transaction,
        userId: userId,
        key: _biometricPromptedKey,
        value: '1',
      );
    });
  }

  Future<void> markBiometricPrompted(String userId) {
    return _upsertSetting(
      _database,
      userId: userId,
      key: _biometricPromptedKey,
      value: '1',
    );
  }

  Future<void> _persistAuthentication(AuthSession session) async {
    try {
      await _database.rawInsert(
        '''
        INSERT INTO users (id, username, created_at, last_login_at)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          username = excluded.username,
          created_at = excluded.created_at,
          last_login_at = excluded.last_login_at
        ''',
        [
          session.user.id,
          session.user.username,
          _normalizeUtcSeconds(session.user.createdAt),
          _utcNowWithoutMilliseconds(),
        ],
      );
    } on DatabaseException {
      throw const AuthException(
        type: AuthFailureType.localStorage,
        message: 'Profil tidak dapat disimpan di perangkat. Silakan coba lagi.',
      );
    }

    try {
      await _sessionStorage.saveSession(
        token: session.token,
        userId: session.user.id,
        expiresAt: _normalizeUtcSeconds(session.expiresAt),
      );
    } on SessionStorageException {
      throw const AuthException(
        type: AuthFailureType.localStorage,
        message: 'Sesi tidak dapat disimpan dengan aman. Silakan coba lagi.',
      );
    }
  }

  Future<bool> _isSettingEnabled(String userId, String key) async {
    final rows = await _database.query(
      'settings',
      columns: ['value'],
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, key],
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['value'] == '1';
  }

  Future<void> _upsertSetting(
    DatabaseExecutor database, {
    required String userId,
    required String key,
    required String value,
  }) {
    return database.rawInsert(
      '''
      INSERT INTO settings (user_id, key, value)
      VALUES (?, ?, ?)
      ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value
      ''',
      [userId, key, value],
    );
  }

  String _utcNowWithoutMilliseconds() {
    return _formatUtcSeconds(DateTime.now().toUtc());
  }

  String _normalizeUtcSeconds(String value) {
    return _formatUtcSeconds(DateTime.parse(value).toUtc());
  }

  String _formatUtcSeconds(DateTime value) {
    return value.toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');
  }
}
