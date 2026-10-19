import 'package:sqflite/sqflite.dart';

import '../remote/auth_client.dart';
import '../secure/session_storage.dart';

class UserRepository {
  const UserRepository(this._database, this._authClient, this._sessionStorage);

  final Database _database;
  final AuthClient _authClient;
  final SessionStorage _sessionStorage;

  Future<void> register({
    required String username,
    required String password,
  }) async {
    final session = await _authClient.register(
      username: username,
      password: password,
    );
    await _persistAuthentication(session);
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final session = await _authClient.login(
      username: username,
      password: password,
    );
    await _persistAuthentication(session);
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
