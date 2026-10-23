import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../secure/session_storage.dart';

enum AiFailure {
  network,
  timeout,
  invalidInput,
  unauthorized,
  rateLimited,
  invalidOutput,
  upstream,
  server,
}

class AiException implements Exception {
  const AiException(
    this.failure,
    this.message, {
    this.retryAfterSeconds,
    this.upstreamStatus,
  });

  final AiFailure failure;
  final String message;
  final int? retryAfterSeconds;
  final int? upstreamStatus;

  @override
  String toString() => message;
}

class ChatResponse {
  const ChatResponse({required this.reply, this.remainingToday});

  final String reply;
  final int? remainingToday;
}

class AiClient {
  AiClient({
    required this.sessionStorage,
    http.Client? client,
    this.baseUrl = AppConfig.functionsBaseUrl,
    this.timeout = const Duration(seconds: 35),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final SessionStorage sessionStorage;
  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final Duration timeout;

  Future<Map<String, dynamic>> recommend({
    required String userId,
    required Map<String, Object?> payload,
  }) => _request(userId: userId, type: 'recommend', payload: payload);

  Future<Map<String, dynamic>> diagnose({
    required String userId,
    required Map<String, Object?> payload,
  }) => _request(userId: userId, type: 'diagnose', payload: payload);

  Future<ChatResponse> chat({
    required String userId,
    required List<Map<String, String>> messages,
    Map<String, Object?>? context,
  }) async {
    final response = await _request(
      userId: userId,
      type: 'chat',
      payload: {'messages': messages, 'context': ?context},
    );
    final reply = response['reply'];
    final remaining = response['remaining_today'];
    if (reply is! String ||
        reply.trim().isEmpty ||
        reply.length > 1200 ||
        (remaining != null &&
            (remaining is! int || remaining < 0 || remaining > 20))) {
      throw const AiException(
        AiFailure.invalidOutput,
        'Jawaban barista tidak valid. Coba lagi.',
      );
    }
    return ChatResponse(reply: reply.trim(), remainingToday: remaining as int?);
  }

  Future<Map<String, dynamic>> _request({
    required String userId,
    required String type,
    required Map<String, Object?> payload,
  }) async {
    late final StoredSession? session;
    try {
      session = await sessionStorage.readSession();
    } on SessionStorageException {
      throw const AiException(
        AiFailure.server,
        'Sesi tidak dapat dibaca. Coba lagi.',
      );
    }
    if (session == null || session.userId != userId) {
      throw const AiException(
        AiFailure.unauthorized,
        'Sesi tidak sah. Masuk kembali.',
      );
    }

    late final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/ai'),
            headers: {
              'Content-Type': 'application/json',
              'x-session-token': session.token,
            },
            body: jsonEncode({'type': type, 'payload': payload}),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw AiException(
        AiFailure.timeout,
        type == 'chat'
            ? 'Barista terlalu lama merespons. Coba lagi.'
            : 'AI terlalu lama merespons. Pengaturan cadangan tersedia.',
      );
    } on SocketException {
      throw AiException(
        AiFailure.network,
        type == 'chat'
            ? 'Tidak dapat terhubung ke internet. Coba lagi.'
            : 'Tidak dapat terhubung ke internet. Pengaturan cadangan tersedia.',
      );
    } on http.ClientException {
      throw AiException(
        AiFailure.network,
        type == 'chat'
            ? 'Tidak dapat terhubung ke internet. Coba lagi.'
            : 'Tidak dapat terhubung ke internet. Pengaturan cadangan tersedia.',
      );
    }

    final upstreamStatus = response.statusCode == 200
        ? null
        : _upstreamStatus(response.body);
    switch (response.statusCode) {
      case 200:
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) return decoded;
        } on FormatException {
          // Respons rusak memakai fallback di pemanggil.
        }
        throw AiException(
          AiFailure.invalidOutput,
          type == 'chat'
              ? 'Jawaban barista tidak valid. Coba lagi.'
              : 'Saran AI tidak dapat dipakai. Pengaturan cadangan tersedia.',
        );
      case 400:
        throw AiException(
          AiFailure.invalidInput,
          'Data untuk AI tidak valid. Periksa isian dan coba lagi.',
          upstreamStatus: upstreamStatus,
        );
      case 401:
        throw AiException(
          AiFailure.unauthorized,
          'Sesi tidak sah. Masuk kembali.',
          upstreamStatus: upstreamStatus,
        );
      case 429:
        final retryAfter = _retryAfterSeconds(response.body);
        throw AiException(
          AiFailure.rateLimited,
          type == 'chat'
              ? 'Batas chat hari ini tercapai. Coba lagi besok.'
              : retryAfter == null
              ? 'Batas pemakaian AI tercapai, coba lagi nanti.'
              : 'Batas pemakaian AI tercapai, coba lagi dalam ${(retryAfter / 60).ceil()} menit.',
          retryAfterSeconds: retryAfter,
          upstreamStatus: upstreamStatus,
        );
      case 504:
        throw AiException(
          AiFailure.timeout,
          type == 'chat'
              ? 'Barista terlalu lama merespons. Coba lagi.'
              : 'AI terlalu lama merespons. Pengaturan cadangan tersedia.',
          upstreamStatus: upstreamStatus,
        );
      case 502:
        if (_errorCode(response.body) == 'ai_invalid_output') {
          throw AiException(
            AiFailure.invalidOutput,
            type == 'chat'
                ? 'Jawaban barista tidak valid. Coba lagi.'
                : 'Saran AI tidak dapat dipakai. Pengaturan cadangan tersedia.',
            upstreamStatus: upstreamStatus,
          );
        }
        throw AiException(
          AiFailure.upstream,
          type == 'chat'
              ? 'Layanan barista sedang bermasalah. Coba lagi.'
              : 'Layanan AI sedang bermasalah. Pengaturan cadangan tersedia.',
          upstreamStatus: upstreamStatus,
        );
      case 500:
        if (_errorCode(response.body) == 'server_configuration_error') {
          throw AiException(
            AiFailure.server,
            'Layanan AI belum siap. Pengaturan cadangan tersedia.',
            upstreamStatus: upstreamStatus,
          );
        }
        throw AiException(
          AiFailure.server,
          'Layanan AI gagal. Pengaturan cadangan tersedia.',
          upstreamStatus: upstreamStatus,
        );
      default:
        throw AiException(
          AiFailure.server,
          'Layanan AI gagal. Pengaturan cadangan tersedia.',
          upstreamStatus: upstreamStatus,
        );
    }
  }

  static int? _retryAfterSeconds(String body) {
    try {
      final decoded = jsonDecode(body);
      final details = (decoded as Map<String, dynamic>)['error']?['details'];
      final value = (details as Map<String, dynamic>)['retry_after_s'];
      return value is int && value > 0 ? value : null;
    } catch (_) {
      return null;
    }
  }

  static String? _errorCode(String body) {
    try {
      final decoded = jsonDecode(body);
      return (decoded as Map<String, dynamic>)['error']?['code'] as String?;
    } catch (_) {
      return null;
    }
  }

  static int? _upstreamStatus(String body) {
    try {
      final decoded = jsonDecode(body);
      final details = (decoded as Map<String, dynamic>)['error']?['details'];
      final value = (details as Map<String, dynamic>)['upstream_status'];
      return value is int ? value : null;
    } catch (_) {
      return null;
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
