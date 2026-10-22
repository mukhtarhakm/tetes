import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../secure/session_storage.dart';

enum SyncFailure {
  network,
  timeout,
  badRequest,
  unauthorized,
  tooManyBeans,
  server,
}

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

class SyncGroupPage {
  const SyncGroupPage(this.rows, this.hasMore, this.cursorAt, this.cursorId);
  final List<Map<String, dynamic>> rows;
  final bool hasMore;
  final String? cursorAt;
  final String? cursorId;
}

class SyncPullResponse {
  const SyncPullResponse({
    required this.status,
    required this.serverLastSeq,
    required this.hasMore,
    required this.beans,
    required this.brews,
  });

  final String status;
  final int serverLastSeq;
  final bool hasMore;
  final List<Map<String, dynamic>> beans;
  final List<Map<String, dynamic>> brews;
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

  Future<SyncPushResponse> pushGroup({
    required String userId,
    required String group,
    required List<Map<String, Object?>> rows,
  }) async {
    final data = await _post(userId, 'sync-push', {
      'beans': [],
      'brews': [],
      group: rows,
    });
    final accepted = data['accepted'];
    final rejected = data['rejected'];
    if (accepted is! Map<String, dynamic> ||
        accepted[group] is! List ||
        rejected is! List) {
      throw const SyncException(
        SyncFailure.server,
        'Respons sinkronisasi tidak valid. Coba lagi.',
      );
    }
    try {
      return SyncPushResponse(
        accepted: {group: (accepted[group] as List).cast<String>()},
        rejected: rejected
            .map(
              (item) => SyncRejection(
                item['table'] as String,
                item['id'] as String,
                item['reason'] as String,
              ),
            )
            .toList(),
      );
    } catch (_) {
      throw const SyncException(
        SyncFailure.server,
        'Respons sinkronisasi tidak valid. Coba lagi.',
      );
    }
  }

  Future<SyncGroupPage> pullGroup({
    required String userId,
    required String group,
    String? cursorAt,
    String? cursorId,
  }) async {
    final data = await _post(userId, 'sync-pull', {
      'group': group,
      'cursor_at': cursorAt,
      'cursor_id': cursorId,
    });
    try {
      final rows = (data['rows'] as List).cast<Map<String, dynamic>>();
      final more = data['has_more'] as bool;
      final at = data['cursor_at'] as String?;
      final id = data['cursor_id'] as String?;
      if (data['group'] != group || more && (at == null || id == null)) {
        throw const FormatException();
      }
      return SyncGroupPage(rows, more, at, id);
    } catch (_) {
      throw const SyncException(
        SyncFailure.server,
        'Respons tarik data tidak valid. Coba lagi.',
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    String userId,
    String function,
    Map<String, Object?> body,
  ) async {
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
            Uri.parse('$baseUrl/$function'),
            headers: {
              'Content-Type': 'application/json',
              'x-session-token': session.token,
            },
            body: jsonEncode(body),
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
    if (response.statusCode == 401) {
      throw const SyncException(
        SyncFailure.unauthorized,
        'Sesi tidak sah. Masuk kembali.',
      );
    }
    if (response.statusCode != 200) {
      throw const SyncException(
        SyncFailure.server,
        'Server sinkronisasi sedang bermasalah. Coba lagi.',
      );
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const SyncException(
        SyncFailure.server,
        'Respons sinkronisasi tidak valid. Coba lagi.',
      );
    }
  }

  Future<SyncPullResponse> pullData({
    required String userId,
    required int lastSeq,
    required String? lastHash,
  }) async {
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
            Uri.parse('$baseUrl/sync-pull'),
            headers: {
              'Content-Type': 'application/json',
              'x-session-token': session.token,
            },
            body: jsonEncode({'last_seq': lastSeq, 'last_hash': lastHash}),
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
          'Permintaan tarik data ditolak.',
        );
      case 401:
        throw const SyncException(
          SyncFailure.unauthorized,
          'Sesi tidak sah. Masuk kembali.',
        );
      case 413:
        throw const SyncException(
          SyncFailure.tooManyBeans,
          'Jumlah biji di server melebihi batas 500.',
        );
      case 200:
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic> ||
              !const [
                'pull',
                'empty_server',
                'up_to_date',
                'local_ahead',
                'diverged',
              ].contains(decoded['status']) ||
              decoded['server_last_seq'] is! int ||
              decoded['has_more'] is! bool ||
              decoded['beans'] is! List ||
              decoded['brews'] is! List) {
            throw const FormatException();
          }
          final beans = (decoded['beans'] as List).cast<Map<String, dynamic>>();
          final brews = (decoded['brews'] as List).cast<Map<String, dynamic>>();
          return SyncPullResponse(
            status: decoded['status'] as String,
            serverLastSeq: decoded['server_last_seq'] as int,
            hasMore: decoded['has_more'] as bool,
            beans: beans,
            brews: brews,
          );
        } on FormatException {
          throw const SyncException(
            SyncFailure.server,
            'Respons tarik data tidak valid. Coba lagi.',
          );
        } on TypeError {
          throw const SyncException(
            SyncFailure.server,
            'Respons tarik data tidak valid. Coba lagi.',
          );
        }
      default:
        throw const SyncException(
          SyncFailure.server,
          'Server sinkronisasi sedang bermasalah. Coba lagi.',
        );
    }
  }

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
