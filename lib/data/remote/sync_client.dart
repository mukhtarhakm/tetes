import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../secure/session_storage.dart';

enum SyncFailure { network, timeout, badRequest, unauthorized, server }

class SyncException implements Exception {
  const SyncException(this.failure, this.message);

  final SyncFailure failure;
  final String message;

  @override
  String toString() => message;
}

class SyncPushResponse {
  const SyncPushResponse({required this.accepted, required this.rejected});

  final Map<String, List<String>> accepted;
  final List<SyncRejection> rejected;
}

class SyncRejection {
  const SyncRejection(this.table, this.id, this.reason);

  final String table;
  final String id;
  final String reason;
}

class SyncClient {
  SyncClient({
    required this.sessionStorage,
    http.Client? client,
    this.baseUrl = AppConfig.functionsBaseUrl,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final SessionStorage sessionStorage;
  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final Duration timeout;

  Future<SyncPushResponse> push({
    required String userId,
    required List<Map<String, Object?>> beans,
    required List<Map<String, Object?>> brews,
  }) async {
    if (beans.length > 100 || brews.length > 50) {
      throw const SyncException(
        SyncFailure.badRequest,
        'Terlalu banyak data dalam satu kiriman.',
      );
    }
    final session = await sessionStorage.readSession();
    if (session == null || session.userId != userId) {
      throw const SyncException(
        SyncFailure.unauthorized,
        'Sesi tidak sah. Masuk kembali.',
      );
    }
    late http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/sync-push'),
            headers: {
              'Content-Type': 'application/json',
              'x-session-token': session.token,
            },
            body: jsonEncode({'beans': beans, 'brews': brews}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const SyncException(
        SyncFailure.timeout,
        'Sinkronisasi terlalu lama. Coba lagi.',
      );
    } on SocketException {
      throw const SyncException(
        SyncFailure.network,
        'Tidak dapat terhubung ke internet.',
      );
    } on http.ClientException {
      throw const SyncException(
        SyncFailure.network,
        'Tidak dapat terhubung ke internet.',
      );
    }
    switch (response.statusCode) {
      case 400:
        throw const SyncException(
          SyncFailure.badRequest,
          'Data sinkronisasi ditolak. Periksa data dan coba lagi.',
        );
      case 401:
        throw const SyncException(
          SyncFailure.unauthorized,
          'Sesi tidak sah. Masuk kembali.',
        );
      case 200:
        return _parse(response.body);
      default:
        throw const SyncException(
          SyncFailure.server,
          'Server sinkronisasi sedang bermasalah. Coba lagi.',
        );
    }
  }

  SyncPushResponse _parse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic> ||
          decoded['accepted'] is! Map<String, dynamic> ||
          decoded['rejected'] is! List) {
        throw const FormatException();
      }
      final accepted = decoded['accepted'] as Map<String, dynamic>;
      final beans = accepted['beans'];
      final brews = accepted['brews'];
      if (beans is! List ||
          brews is! List ||
          beans.any((id) => id is! String) ||
          brews.any((id) => id is! String)) {
        throw const FormatException();
      }
      final rejected = <SyncRejection>[];
      for (final item in decoded['rejected'] as List) {
        if (item is! Map<String, dynamic> ||
            item['table'] is! String ||
            item['id'] is! String ||
            item['reason'] is! String) {
          throw const FormatException();
        }
        rejected.add(
          SyncRejection(
            item['table'] as String,
            item['id'] as String,
            item['reason'] as String,
          ),
        );
      }
      return SyncPushResponse(
        accepted: {
          'beans': beans.cast<String>(),
          'brews': brews.cast<String>(),
        },
        rejected: rejected,
      );
    } on FormatException {
      throw const SyncException(
        SyncFailure.server,
        'Respons sinkronisasi tidak valid. Coba lagi.',
      );
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
