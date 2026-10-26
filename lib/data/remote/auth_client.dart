import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../features/auth/auth_validation.dart';
import '../secure/biometric_credential_storage.dart';
import 'password_hash.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.createdAt,
  });
  final String id;
  final String username;
  final String createdAt;
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.token,
    required this.expiresAt,
  });
  final AuthUser user;
  final String token;
  final String expiresAt;
}

enum AuthFailureType {
  invalidInput,
  invalidCredentials,
  usernameTaken,
  rateLimited,
  network,
  timeout,
  localStorage,
  server,
}

class AuthException implements Exception {
  const AuthException({
    required this.type,
    required this.message,
    this.fieldErrors = const {},
    this.retryAfterMinutes,
  });
  final AuthFailureType type;
  final String message;
  final Map<String, String> fieldErrors;
  final int? retryAfterMinutes;
  @override
  String toString() => message;
}

abstract interface class SessionRevocationClient {
  Future<void> revokeSession({required String token, Duration? requestTimeout});
}

class AuthClient implements SessionRevocationClient {
  AuthClient({
    http.Client? client,
    this.baseUrl = AppConfig.supabaseRestBaseUrl,
    this.timeout = AppConfig.authRequestTimeout,
    String? apiKey,
    FlutterSecureStorage? rateLimitStorage,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null,
       _apiKey = apiKey ?? AppConfig.supabaseAnonKey,
       _rateLimitStorage = rateLimitStorage ?? const FlutterSecureStorage();

  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final Duration timeout;
  final String _apiKey;
  final FlutterSecureStorage _rateLimitStorage;
  Future<void> _loginQueue = Future.value();

  Future<AuthSession> register({
    required String username,
    required String password,
  }) async {
    _validate(username, password);
    _checkConfiguration();
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final passwordHash = await derivePasswordHash(
      password,
      salt,
      passwordIterations,
    );
    final response = await _send(
      () => _client.post(
        Uri.parse('$baseUrl/users?select=id,username,created_at'),
        headers: _headers({
          'x-login-username': username,
          'Prefer': 'return=representation',
        }),
        body: jsonEncode({
          'username': username,
          'password_hash': base64Encode(passwordHash),
          'salt': base64Encode(salt),
          'iterations': passwordIterations,
          'algo': passwordAlgorithm,
        }),
      ),
    );
    if (response.statusCode == 409 ||
        _asObject(_decode(response.body))?['code'] == '23505') {
      throw const AuthException(
        type: AuthFailureType.usernameTaken,
        message: 'Username sudah digunakan.',
        fieldErrors: {'username': 'Username sudah digunakan.'},
      );
    }
    if (response.statusCode != 201) throw _serverError();
    final rows = _decode(response.body);
    if (rows is! List || rows.length != 1) throw _serverError();
    final user = _parseUser(rows.single);
    try {
      return await _createSession(user);
    } catch (_) {
      throw const AuthException(
        type: AuthFailureType.server,
        message: 'Akun dibuat. Silakan masuk.',
      );
    }
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) {
    final result = _loginQueue.then((_) => _login(username, password));
    _loginQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<AuthSession> _login(String username, String password) async {
    _validate(username, password);
    _checkConfiguration();
    await _checkRateLimit(username);
    final row = await _fetchUserRow(username);
    var salt = List<int>.filled(16, 0);
    var expected = List<int>.filled(32, 0);
    var iterations = passwordIterations;
    var valid = false;
    if (row != null &&
        row['algo'] == passwordAlgorithm &&
        row['iterations'] is int &&
        (row['iterations'] as int) > 0) {
      try {
        final decodedSalt = base64Decode(row['salt'] as String);
        final decodedHash = base64Decode(row['password_hash'] as String);
        if (decodedSalt.length == 16 && decodedHash.length == 32) {
          salt = decodedSalt;
          expected = decodedHash;
          iterations = row['iterations'] as int;
          valid = true;
        }
      } catch (_) {
        valid = false;
      }
    }
    final actual = await derivePasswordHash(password, salt, iterations);
    if (!valid || !constantTimeEquals(actual, expected)) {
      await _recordFailure(username);
      throw _invalidCredentials();
    }
    final user = _parseUser(row);
    final session = await _createSession(user);
    await _clearFailures(username);
    return session;
  }

  Future<BiometricCredential> biometricCredential(String username) async {
    _checkConfiguration();
    final row = await _fetchUserRow(username);
    if (row == null) throw _invalidCredentials();
    try {
      return _biometricCredentialFromRow(username, row);
    } catch (_) {
      throw _serverError();
    }
  }

  Future<AuthSession> loginBiometric(
    BiometricCredential stored, {
    String? expectedUserId,
  }) async {
    _checkConfiguration();
    final row = await _fetchUserRow(stored.username);
    if (row == null) {
      await _recordFailure(stored.username);
      throw _invalidCredentials();
    }
    try {
      final server = _biometricCredentialFromRow(stored.username, row);
      final matches =
          stored.algo == server.algo &&
          stored.iterations == server.iterations &&
          stored.salt == server.salt &&
          constantTimeEquals(
            base64Decode(stored.passwordHash),
            base64Decode(server.passwordHash),
          );
      if (!matches) throw const FormatException();
    } catch (_) {
      await _recordFailure(stored.username);
      throw _invalidCredentials();
    }
    final user = _parseUser(row);
    if (expectedUserId != null && user.id != expectedUserId) {
      await _recordFailure(stored.username);
      throw _invalidCredentials();
    }
    final session = await _createSession(user);
    await _clearFailures(stored.username);
    return session;
  }

  BiometricCredential _biometricCredentialFromRow(
    String username,
    Map<String, dynamic> row,
  ) {
    final credential = BiometricCredential(
      username: username,
      passwordHash: row['password_hash'] as String,
      salt: row['salt'] as String,
      iterations: row['iterations'] as int,
      algo: row['algo'] as String,
    );
    if (credential.algo != passwordAlgorithm ||
        credential.iterations < 1 ||
        base64Decode(credential.salt).length != 16 ||
        base64Decode(credential.passwordHash).length != 32) {
      throw const FormatException();
    }
    return credential;
  }

  Future<Map<String, dynamic>?> _fetchUserRow(String username) async {
    final uri = Uri.parse('$baseUrl/users').replace(
      queryParameters: {
        'username': 'eq.$username',
        'select': 'id,username,password_hash,salt,iterations,algo,created_at',
        'limit': '1',
      },
    );
    final response = await _send(
      () => _client.get(uri, headers: _headers({'x-login-username': username})),
    );
    if (response.statusCode == 401) return null;
    if (response.statusCode != 200) throw _serverError();
    final rows = _decode(response.body);
    if (rows is! List || rows.length > 1) throw _serverError();
    return rows.isEmpty ? null : _asObject(rows.single);
  }

  @override
  Future<void> revokeSession({
    required String token,
    Duration? requestTimeout,
  }) async {
    _checkConfiguration();
    final hash = sha256.convert(utf8.encode(token)).toString();
    final uri = Uri.parse(
      '$baseUrl/sessions',
    ).replace(queryParameters: {'token_hash': 'eq.$hash'});
    final response = await _send(
      () => _client.patch(
        uri,
        headers: _headers({'x-token-hash': hash, 'Prefer': 'return=minimal'}),
        body: jsonEncode({'revoked': true}),
      ),
      requestTimeout: requestTimeout,
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw const AuthException(
        type: AuthFailureType.server,
        message: 'Sesi server belum dapat dicabut.',
      );
    }
  }

  Future<AuthSession> _createSession(AuthUser user) async {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    final hash = sha256.convert(utf8.encode(token)).toString();
    final expiresAt = _utcSeconds(DateTime.now().toUtc().add(_sessionDuration));
    final response = await _send(
      () => _client.post(
        Uri.parse('$baseUrl/sessions'),
        headers: _headers({'Prefer': 'return=minimal'}),
        body: jsonEncode({
          'user_id': user.id,
          'token_hash': hash,
          'expires_at': expiresAt,
        }),
      ),
    );
    if (response.statusCode != 201) throw _serverError();
    return AuthSession(user: user, token: token, expiresAt: expiresAt);
  }

  Map<String, String> _headers([Map<String, String> extra = const {}]) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'apikey': _apiKey,
    'Authorization': 'Bearer $_apiKey',
    ...extra,
  };

  void _checkConfiguration() {
    if (!baseUrl.startsWith('https://') || _apiKey.isEmpty) {
      throw const AuthException(
        type: AuthFailureType.server,
        message:
            'Konfigurasi Supabase belum tersedia. Isi env/app.json lalu jalankan ulang aplikasi.',
      );
    }
  }

  void _validate(String username, String password) {
    final fields = <String, String>{};
    final usernameError = AuthValidation.username(username);
    final passwordError = AuthValidation.password(password);
    if (usernameError != null) fields['username'] = usernameError;
    if (passwordError != null) fields['password'] = passwordError;
    if (fields.isNotEmpty) {
      throw AuthException(
        type: AuthFailureType.invalidInput,
        message: 'Periksa kembali data yang kamu masukkan.',
        fieldErrors: fields,
      );
    }
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request, {
    Duration? requestTimeout,
  }) async {
    try {
      return await request().timeout(requestTimeout ?? timeout);
    } on TimeoutException {
      throw const AuthException(
        type: AuthFailureType.timeout,
        message: 'Server membutuhkan waktu terlalu lama. Silakan coba lagi.',
      );
    } on SocketException {
      throw const AuthException(
        type: AuthFailureType.network,
        message: 'Internet diperlukan untuk masuk atau mendaftar.',
      );
    } on http.ClientException {
      throw const AuthException(
        type: AuthFailureType.network,
        message: 'Internet diperlukan untuk masuk atau mendaftar.',
      );
    }
  }

  AuthUser _parseUser(Object? value) {
    final row = _asObject(value);
    final id = row?['id'];
    final username = row?['username'];
    final createdAt = row?['created_at'];
    if (id is! String ||
        id.isEmpty ||
        username is! String ||
        username.isEmpty ||
        createdAt is! String ||
        DateTime.tryParse(createdAt) == null) {
      throw _serverError();
    }
    return AuthUser(id: id, username: username, createdAt: createdAt);
  }

  Object? _decode(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic>? _asObject(Object? value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry('$key', item));
  }

  AuthException _invalidCredentials() => const AuthException(
    type: AuthFailureType.invalidCredentials,
    message: 'Username atau password salah',
  );
  AuthException _serverError() => const AuthException(
    type: AuthFailureType.server,
    message: 'Server sedang bermasalah. Silakan coba lagi.',
  );

  // Policy sessions di database membatasi expires_at maksimal 7 hari dari jam server;
  // selisih jam HP dikurangi supaya pembuatan sesi tidak ditolak.
  static const _sessionDuration = Duration(days: 6, hours: 23);

  static const _windowMs = 15 * 60 * 1000;
  String _attemptKey(String username) => 'auth_attempts_$username';

  // shortcut: pembatasan lokal hanya pengaman UX; pertahanan keamanan memerlukan server.
  Future<void> _checkRateLimit(String username) async {
    if (await _readAttempts(username) >= 5) {
      final remainingMs =
          _windowMs - DateTime.now().toUtc().millisecondsSinceEpoch % _windowMs;
      final minutes = (remainingMs / Duration.millisecondsPerMinute).ceil();
      throw AuthException(
        type: AuthFailureType.rateLimited,
        message:
            'Terlalu banyak percobaan login. Coba lagi dalam $minutes menit.',
        retryAfterMinutes: minutes,
      );
    }
  }

  Future<int> _readAttempts(String username) async {
    try {
      final value = await _rateLimitStorage.read(key: _attemptKey(username));
      final parts = value?.split(':');
      final window = DateTime.now().toUtc().millisecondsSinceEpoch ~/ _windowMs;
      return parts?.length == 2 && int.tryParse(parts![0]) == window
          ? (int.tryParse(parts[1]) ?? 0).clamp(0, 5)
          : 0;
    } catch (_) {
      throw const AuthException(
        type: AuthFailureType.localStorage,
        message: 'Batas percobaan login tidak dapat dibaca. Silakan coba lagi.',
      );
    }
  }

  Future<void> _recordFailure(String username) async {
    final count = await _readAttempts(username);
    try {
      final window = DateTime.now().toUtc().millisecondsSinceEpoch ~/ _windowMs;
      await _rateLimitStorage.write(
        key: _attemptKey(username),
        value: '$window:${count + 1}',
      );
    } catch (_) {
      throw const AuthException(
        type: AuthFailureType.localStorage,
        message:
            'Batas percobaan login tidak dapat disimpan. Silakan coba lagi.',
      );
    }
  }

  Future<void> _clearFailures(String username) async {
    try {
      await _rateLimitStorage.delete(key: _attemptKey(username));
    } catch (_) {
      throw const AuthException(
        type: AuthFailureType.localStorage,
        message:
            'Batas percobaan login tidak dapat dihapus. Silakan coba lagi.',
      );
    }
  }

  String _utcSeconds(DateTime dateTime) =>
      dateTime.toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');
  void close() {
    if (_ownsClient) _client.close();
  }
}
