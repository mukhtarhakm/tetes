import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

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
    this.baseUrl = AppConfig.functionsBaseUrl,
    this.timeout = AppConfig.authRequestTimeout,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final Duration timeout;

  Future<AuthSession> register({
    required String username,
    required String password,
  }) {
    return _authenticate(
      functionName: 'auth-register',
      username: username,
      password: password,
    );
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) {
    return _authenticate(
      functionName: 'auth-login',
      username: username,
      password: password,
    );
  }

  @override
  Future<void> revokeSession({
    required String token,
    Duration? requestTimeout,
  }) async {
    late http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/auth-logout'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'x-session-token': token,
            },
            body: '{}',
          )
          .timeout(requestTimeout ?? timeout);
    } on TimeoutException {
      throw const AuthException(
        type: AuthFailureType.timeout,
        message: 'Server membutuhkan waktu terlalu lama. Silakan coba lagi.',
      );
    } on SocketException {
      throw const AuthException(
        type: AuthFailureType.network,
        message: 'Tidak dapat terhubung ke internet.',
      );
    } on http.ClientException {
      throw const AuthException(
        type: AuthFailureType.network,
        message: 'Tidak dapat terhubung ke internet.',
      );
    }

    if (response.statusCode != 200) {
      throw const AuthException(
        type: AuthFailureType.server,
        message: 'Sesi server belum dapat dicabut.',
      );
    }
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<AuthSession> _authenticate({
    required String functionName,
    required String username,
    required String password,
  }) async {
    late http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/$functionName'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(timeout);
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

    final responseBody = _decodeObject(response.body);
    if (response.statusCode == 200) {
      return _parseSession(responseBody);
    }

    final error = _asObject(responseBody?['error']);
    final details = _asObject(error?['details']);
    return switch (response.statusCode) {
      400 => throw AuthException(
        type: AuthFailureType.invalidInput,
        message: 'Periksa kembali data yang kamu masukkan.',
        fieldErrors: _parseFieldErrors(details?['fields']),
      ),
      401 => throw const AuthException(
        type: AuthFailureType.invalidCredentials,
        message: 'Username atau password salah',
      ),
      409 => throw const AuthException(
        type: AuthFailureType.usernameTaken,
        message: 'Username sudah digunakan.',
        fieldErrors: {'username': 'Username sudah digunakan.'},
      ),
      429 => throw _rateLimitedException(details),
      _ => throw const AuthException(
        type: AuthFailureType.server,
        message: 'Server sedang bermasalah. Silakan coba lagi.',
      ),
    };
  }

  AuthSession _parseSession(Map<String, dynamic>? body) {
    final user = _asObject(body?['user']);
    final id = user?['id'];
    final username = user?['username'];
    final createdAt = user?['created_at'];
    final token = body?['session_token'];
    final expiresAt = body?['expires_at'];

    if (id is! String ||
        username is! String ||
        createdAt is! String ||
        token is! String ||
        expiresAt is! String ||
        id.isEmpty ||
        username.isEmpty ||
        token.isEmpty ||
        DateTime.tryParse(createdAt) == null ||
        DateTime.tryParse(expiresAt) == null) {
      throw const AuthException(
        type: AuthFailureType.server,
        message: 'Respons server tidak valid. Silakan coba lagi.',
      );
    }

    return AuthSession(
      user: AuthUser(id: id, username: username, createdAt: createdAt),
      token: token,
      expiresAt: expiresAt,
    );
  }

  AuthException _rateLimitedException(Map<String, dynamic>? details) {
    final retryAfterSeconds = details?['retry_after_s'];
    final seconds = retryAfterSeconds is num
        ? retryAfterSeconds.ceil()
        : int.tryParse('$retryAfterSeconds');
    final minutes = seconds == null || seconds <= 0
        ? 1
        : (seconds / Duration.secondsPerMinute).ceil();

    return AuthException(
      type: AuthFailureType.rateLimited,
      message:
          'Terlalu banyak percobaan login. Coba lagi dalam $minutes menit.',
      retryAfterMinutes: minutes,
    );
  }

  Map<String, dynamic>? _decodeObject(String source) {
    try {
      return _asObject(jsonDecode(source));
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic>? _asObject(Object? value) {
    if (value is! Map) {
      return null;
    }
    return value.map((key, item) => MapEntry('$key', item));
  }

  Map<String, String> _parseFieldErrors(Object? value) {
    final fields = _asObject(value);
    if (fields == null) {
      return const {};
    }

    return {
      for (final entry in fields.entries)
        if (entry.value is String) entry.key: entry.value as String,
    };
  }
}
