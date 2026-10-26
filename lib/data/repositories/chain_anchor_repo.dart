import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../db/database_provider.dart';

final chainAnchorRepositoryProvider = FutureProvider<ChainAnchorRepository>(
  (ref) async =>
      ChainAnchorRepository(await ref.watch(databaseProvider.future)),
);

final clearChainAnchorsProvider = Provider<Future<void> Function(String)>(
  (ref) =>
      (userId) async =>
          (await ref.read(chainAnchorRepositoryProvider.future)).clear(userId),
);

class ChainAnchorRecord {
  const ChainAnchorRecord({
    required this.userId,
    required this.seq,
    required this.status,
    required this.anchoredAt,
    this.headHash,
    this.userKey,
    this.txHash,
    this.explorerUrl,
    this.verifiedAt,
    this.verifyResult,
  });

  final String userId;
  final int seq;
  final String status;
  final String anchoredAt;
  final String? headHash;
  final String? userKey;
  final String? txHash;
  final String? explorerUrl;
  final String? verifiedAt;
  final String? verifyResult;

  factory ChainAnchorRecord.fromRow(Map<String, Object?> row) =>
      ChainAnchorRecord(
        userId: row['user_id'] as String,
        seq: row['seq'] as int,
        status: row['status'] as String,
        anchoredAt: row['anchored_at'] as String,
        headHash: row['head_hash'] as String?,
        userKey: row['user_key'] as String?,
        txHash: row['tx_hash'] as String?,
        explorerUrl: row['explorer_url'] as String?,
        verifiedAt: row['verified_at'] as String?,
        verifyResult: row['verify_result'] as String?,
      );
}

class ChainAnchorRepository {
  const ChainAnchorRepository(this._database);

  final Database _database;

  Future<ChainAnchorRecord?> latest(String userId) async {
    final rows = await _database.query(
      'chain_anchors',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'seq DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : ChainAnchorRecord.fromRow(rows.single);
  }

  Future<void> save({
    required String userId,
    required int seq,
    required String status,
    String? headHash,
    String? userKey,
    String? txHash,
    String? explorerUrl,
  }) async {
    final existing = await _database.query(
      'chain_anchors',
      where: 'user_id = ? AND seq = ?',
      whereArgs: [userId, seq],
      limit: 1,
    );
    final previous = existing.isEmpty
        ? null
        : ChainAnchorRecord.fromRow(existing.single);
    await _database.insert('chain_anchors', {
      'user_id': userId,
      'seq': seq,
      'head_hash': headHash ?? previous?.headHash,
      'user_key': userKey ?? previous?.userKey,
      'tx_hash': txHash ?? previous?.txHash,
      'status': status,
      'explorer_url': explorerUrl ?? previous?.explorerUrl,
      'anchored_at': status == 'confirmed'
          ? _now()
          : previous?.anchoredAt ?? _now(),
      'verified_at': previous?.verifiedAt,
      'verify_result': previous?.verifyResult,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveVerification(String userId, int seq, String result) async {
    await _database.update(
      'chain_anchors',
      {'verify_result': result, 'verified_at': _now()},
      where: 'user_id = ? AND seq = ?',
      whereArgs: [userId, seq],
    );
  }

  Future<DateTime?> retryAfter(String userId) async {
    final rows = await _database.query(
      'chain_anchor_cooldowns',
      columns: ['retry_after_at'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : DateTime.parse(rows.single['retry_after_at'] as String);
  }

  Future<void> setRetryAfter(String userId, DateTime time) => _database.insert(
    'chain_anchor_cooldowns',
    {'user_id': userId, 'retry_after_at': _format(time)},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  Future<void> clear(String userId) async {
    await _database.transaction((txn) async {
      await txn.delete(
        'chain_anchors',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await txn.delete(
        'chain_anchor_cooldowns',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    });
  }

  static String _now() => _format(DateTime.now());

  static String _format(DateTime time) =>
      time.toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');
}
