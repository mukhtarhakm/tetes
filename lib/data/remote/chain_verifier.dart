import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

sealed class ChainVerification {
  const ChainVerification();
}

class Match extends ChainVerification {
  const Match(this.seq, this.anchoredAt);
  final int seq;
  final DateTime anchoredAt;
}

class Mismatch extends ChainVerification {
  const Mismatch(this.onChainHash, this.onChainSeq);
  final String onChainHash;
  final int onChainSeq;
}

class NotFound extends ChainVerification {
  const NotFound();
}

class Unknown extends ChainVerification {
  const Unknown(this.message);
  final String message;
}

class Unreachable extends ChainVerification {
  const Unreachable(this.message);
  final String message;
}

class ChainHead extends ChainVerification {
  const ChainHead(this.headHash, this.seq, this.anchoredAt);
  final String headHash;
  final int seq;
  final DateTime anchoredAt;
}

class ChainVerifier {
  ChainVerifier({
    http.Client? client,
    this.rpcUrl = AppConfig.chainRpcUrl,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client(), _ownsClient = client == null;

  // keccak256('latest(bytes32)')[:4], dihitung dengan ethers.
  static const latestSelector = '0x79feb107';
  static const contractAddress = '0x8d80e52E86BDc990f6787D7DD5faF46BeC369324';

  final http.Client _client;
  final bool _ownsClient;
  final String rpcUrl;
  final Duration timeout;

  Future<ChainVerification> verify(String userKey, String localHeadHash) async {
    final head = await readLatest(userKey);
    return head is ChainHead ? compare(head, localHeadHash) : head;
  }

  ChainVerification compare(ChainHead head, String localHeadHash) {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(localHeadHash)) {
      return const Unreachable('Data jangkar tidak valid.');
    }
    if (head.headHash != localHeadHash.toLowerCase()) {
      return Mismatch(head.headHash, head.seq);
    }
    return Match(head.seq, head.anchoredAt);
  }

  ChainVerification compareAtSeq(ChainHead head, String? localHash,
      {bool chainBroken = false}) {
    if (chainBroken) return Mismatch(head.headHash, head.seq);
    if (localHash == null) {
      return const Unknown('Jangkar di rantai lebih baru dari data di perangkat ini');
    }
    return compare(head, localHash);
  }

  Future<ChainVerification> readLatest(String userKey) async {
    if (!RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(userKey) ||
        rpcUrl.isEmpty) {
      return const Unreachable('Data jangkar tidak valid.');
    }
    try {
      final response = await _client.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'eth_call',
          'params': [
            {'to': contractAddress, 'data': '$latestSelector${userKey.substring(2)}'},
            'latest',
          ],
        }),
      ).timeout(timeout);
      if (response.statusCode != 200) throw const FormatException();
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body['error'] != null ||
          body['result'] is! String) {
        throw const FormatException();
      }
      final data = body['result'] as String;
      if (!RegExp(r'^0x[0-9a-fA-F]{192}$').hasMatch(data)) {
        throw const FormatException();
      }
      final hash = data.substring(2, 66).toLowerCase();
      final seq = int.parse(data.substring(66, 130), radix: 16);
      final timestamp = int.parse(data.substring(130, 194), radix: 16);
      if (seq == 0 || RegExp(r'^0+$').hasMatch(hash)) {
        return const NotFound();
      }
      return ChainHead(hash, seq, DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true));
    } on TimeoutException {
      return const Unreachable('Jaringan Sepolia terlalu lama merespons.');
    } on SocketException {
      return const Unreachable('Jaringan Sepolia tidak terjangkau.');
    } on http.ClientException {
      return const Unreachable('Jaringan Sepolia tidak terjangkau.');
    } on FormatException {
      return const Unreachable('Respons jaringan Sepolia tidak valid.');
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
