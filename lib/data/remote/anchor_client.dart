import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../secure/session_storage.dart';

sealed class AnchorResult {
  const AnchorResult();
}

class Confirmed extends AnchorResult {
  const Confirmed({
    required this.seq,
    this.headHash,
    this.userKey,
    this.txHash,
    this.explorerUrl,
    this.alreadyAnchored = false,
  });

  final int seq;
  final String? headHash;
  final String? userKey;
  final String? txHash;
  final String? explorerUrl;
  final bool alreadyAnchored;
}

class Pending extends AnchorResult {
  const Pending(this.seq, this.txHash);
  final int seq;
  final String? txHash;
}

class NothingToAnchor extends AnchorResult {
  const NothingToAnchor();
}

class RateLimited extends AnchorResult {
  const RateLimited(this.retryAfter);
  final Duration retryAfter;
}

class Unauthorized extends AnchorResult {
  const Unauthorized();
}

class Failed extends AnchorResult {
  const Failed(this.message);
  final String message;
}

class AnchorClient {
  AnchorClient({
    required this.sessionStorage,
    http.Client? client,
    this.baseUrl = AppConfig.functionsBaseUrl,
    this.timeout = const Duration(seconds: 40),
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final SessionStorage sessionStorage;
  final http.Client _client;
  final bool _ownsClient;
  final String baseUrl;
  final Duration timeout;

  Future<AnchorResult> requestAnchor(String userId) async {
    final session = await sessionStorage.readSession();
    if (session == null || session.userId != userId) {
      return const Unauthorized();
    }
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/anchor'),
            headers: {
              'Content-Type': 'application/json',
              'x-session-token': session.token,
            },
            body: '{}',
          )
          .timeout(timeout);
      if (response.statusCode == 401) return const Unauthorized();
      if (response.statusCode == 429) {
        final seconds = int.tryParse(
          response.headers['retry-after'] ??
              response.headers['Retry-After'] ??
              '',
        );
        return RateLimited(
          Duration(seconds: seconds == null || seconds < 0 ? 300 : seconds),
        );
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode == 200 || response.statusCode == 202) {
        final seq = body['seq'];
        if (body['anchored'] == true &&
            seq is int &&
            seq > 0 &&
            body['head_hash'] is String &&
            body['user_key'] is String &&
            body['explorer_url'] is String) {
          return Confirmed(
            seq: seq,
            headHash: body['head_hash'] as String,
            userKey: body['user_key'] as String,
            txHash: body['tx_hash'] as String?,
            explorerUrl: body['explorer_url'] as String,
          );
        }
        if (response.statusCode == 200 && body['reason'] == 'no_brews') {
          return const NothingToAnchor();
        }
        if (response.statusCode == 200 &&
            body['reason'] == 'already_anchored' &&
            seq is int &&
            seq > 0) {
          return Confirmed(
            seq: seq,
            txHash: body['tx_hash'] as String?,
            alreadyAnchored: true,
          );
        }
        if (response.statusCode == 202 &&
            body['reason'] == 'pending' &&
            seq is int &&
            seq > 0) {
          return Pending(seq, body['tx_hash'] as String?);
        }
        throw const FormatException();
      }
      final error = body['error'];
      final message = error is Map<String, dynamic> ? error['message'] : null;
      return Failed(
        message is String && message.isNotEmpty
            ? message
            : 'Pencatatan jangkar gagal. Coba lagi.',
      );
    } on TimeoutException {
      return const Failed('Pencatatan terlalu lama. Coba lagi nanti.');
    } on SocketException {
      return const Failed('Tidak dapat terhubung ke internet.');
    } on http.ClientException {
      return const Failed('Tidak dapat terhubung ke internet.');
    } on FormatException {
      return const Failed('Respons jangkar tidak valid. Coba lagi.');
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
