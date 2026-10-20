import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../remote/sync_client.dart';

typedef SyncUnauthorized = Future<void> Function();

class SyncStatus {
  const SyncStatus({
    required this.pendingCount,
    required this.errorCount,
    this.lastSyncAt,
    this.summary,
  });

  final int pendingCount;
  final int errorCount;
  final String? lastSyncAt;
  final Map<String, dynamic>? summary;
}

class SyncService {
  SyncService(this._database, this._client, this._onUnauthorized);

  final Database _database;
  final SyncClient _client;
  final SyncUnauthorized _onUnauthorized;
  bool _running = false;

  void close() => _client.close();

  static const reasonMessages = <String, String>{
    'invalid': 'Data tidak valid.',
    'hash_mismatch': 'Hash seduhan tidak cocok.',
    'chain_broken': 'Urutan rantai seduhan terputus.',
    'tamper': 'Data seduhan berbeda dari yang tersimpan di server.',
    'not_owner': 'Data ini bukan milik akun yang sedang masuk.',
    'chain_blocked': 'Seduhan menunggu perbaikan entri sebelumnya.',
  };

  Future<SyncStatus> status(String userId) async {
    final counts = await _database.rawQuery(
      '''
      SELECT (SELECT COUNT(*) FROM beans WHERE user_id = ? AND sync_status = 'pending') +
             (SELECT COUNT(*) FROM brews WHERE user_id = ? AND sync_status = 'pending') AS pending_count,
             (SELECT COUNT(*) FROM beans WHERE user_id = ? AND sync_status = 'error') +
             (SELECT COUNT(*) FROM brews WHERE user_id = ? AND sync_status = 'error') AS error_count
    ''',
      [userId, userId, userId, userId],
    );
    final settings = await _database.query(
      'settings',
      columns: ['key', 'value'],
      where: 'user_id = ? AND key IN (?, ?)',
      whereArgs: [userId, 'last_sync_at', 'last_sync_summary'],
    );
    final values = {
      for (final row in settings) row['key'] as String: row['value'] as String,
    };
    Map<String, dynamic>? summary;
    final summaryText = values['last_sync_summary'];
    if (summaryText != null) {
      try {
        final decoded = jsonDecode(summaryText);
        if (decoded is Map<String, dynamic>) summary = decoded;
      } on FormatException {
        // Ringkasan rusak tidak menghalangi sinkronisasi data utama.
      }
    }
    return SyncStatus(
      pendingCount: (counts.single['pending_count'] as num).toInt(),
      errorCount: (counts.single['error_count'] as num).toInt(),
      lastSyncAt: values['last_sync_at'],
      summary: summary,
    );
  }

  Future<SyncStatus> run({
    required String userId,
    bool retryErrors = false,
  }) async {
    if (_running) {
      throw const SyncException(
        SyncFailure.badRequest,
        'Sinkronisasi sedang berjalan.',
      );
    }
    _running = true;
    final acceptedCounts = {'beans': 0, 'brews': 0};
    final rejectedCounts = <String, int>{};
    try {
      final states = retryErrors ? ['pending', 'error'] : ['pending'];
      final beans = await _pendingRows(
        'beans',
        userId,
        states,
        'created_at ASC, id ASC',
      );
      for (var start = 0; start < beans.length; start += 100) {
        final batch = beans.skip(start).take(100).toList();
        final response = await _push(
          userId,
          batch.map(_beanJson).toList(),
          const [],
        );
        await _apply(
          'beans',
          userId,
          batch,
          response,
          acceptedCounts,
          rejectedCounts,
        );
        await _saveSummary(userId, acceptedCounts, rejectedCounts);
      }

      final brews = await _pendingRows('brews', userId, states, 'seq ASC');
      for (var start = 0; start < brews.length; start += 50) {
        final batch = brews.skip(start).take(50).toList();
        final payload = <Map<String, Object?>>[];
        for (final brew in batch) {
          final stages = await _database.query(
            'brew_stages',
            where: 'brew_id = ?',
            whereArgs: [brew['id']],
            orderBy: 'position ASC',
          );
          payload.add(_brewJson(brew, stages));
        }
        final response = await _push(userId, const [], payload);
        final blocked = await _apply(
          'brews',
          userId,
          batch,
          response,
          acceptedCounts,
          rejectedCounts,
        );
        await _saveSummary(userId, acceptedCounts, rejectedCounts);
        if (blocked) break;
      }
      if (retryErrors && beans.isEmpty && brews.isEmpty) {
        await _saveSummary(userId, acceptedCounts, rejectedCounts);
      }
      return status(userId);
    } finally {
      _running = false;
    }
  }

  Future<SyncPushResponse> _push(
    String userId,
    List<Map<String, Object?>> beans,
    List<Map<String, Object?>> brews,
  ) async {
    try {
      return await _client.push(userId: userId, beans: beans, brews: brews);
    } on SyncException catch (error) {
      if (error.failure == SyncFailure.unauthorized) await _onUnauthorized();
      rethrow;
    }
  }

  Future<List<Map<String, Object?>>> _pendingRows(
    String table,
    String userId,
    List<String> states,
    String orderBy,
  ) async {
    return _database.query(
      table,
      where:
          'user_id = ? AND sync_status IN (${List.filled(states.length, '?').join(',')})',
      whereArgs: [userId, ...states],
      orderBy: orderBy,
    );
  }

  Map<String, Object?> _beanJson(Map<String, Object?> row) {
    final json = Map<String, Object?>.of(row)
      ..remove('sync_status')
      ..remove('user_id');
    json['is_self_roasted'] = row['is_self_roasted'] == 1;
    json['archived'] = row['archived'] == 1;
    return json;
  }

  Map<String, Object?> _brewJson(
    Map<String, Object?> row,
    List<Map<String, Object?>> stages,
  ) {
    return Map<String, Object?>.of(row)
      ..remove('sync_status')
      ..remove('user_id')
      ..['stages'] = stages
          .map((stage) => Map<String, Object?>.of(stage))
          .toList();
  }

  Future<bool> _apply(
    String table,
    String userId,
    List<Map<String, Object?>> batch,
    SyncPushResponse response,
    Map<String, int> acceptedCounts,
    Map<String, int> rejectedCounts,
  ) async {
    final sent = {for (final row in batch) row['id'] as String: row};
    final accepted = response.accepted[table] ?? const <String>[];
    final rejections = response.rejected
        .where((item) => item.table == table)
        .toList();
    final answered = <String>{};
    for (final id in accepted) {
      if (!sent.containsKey(id) || !answered.add(id)) {
        throw const SyncException(
          SyncFailure.server,
          'Respons sinkronisasi tidak valid. Coba lagi.',
        );
      }
    }
    for (final item in rejections) {
      if (!sent.containsKey(item.id) ||
          !answered.add(item.id) ||
          !reasonMessages.containsKey(item.reason)) {
        throw const SyncException(
          SyncFailure.server,
          'Respons sinkronisasi tidak valid. Coba lagi.',
        );
      }
    }
    if (answered.length != sent.length) {
      throw const SyncException(
        SyncFailure.server,
        'Respons sinkronisasi tidak lengkap. Coba lagi.',
      );
    }
    await _database.transaction((txn) async {
      for (final id in accepted) {
        if (await _markIfUnchanged(txn, table, userId, sent[id]!, 'synced')) {
          acceptedCounts[table] = acceptedCounts[table]! + 1;
        }
      }
      for (final item in rejections) {
        rejectedCounts[item.reason] = (rejectedCounts[item.reason] ?? 0) + 1;
        if (item.reason != 'chain_blocked') {
          await _markIfUnchanged(txn, table, userId, sent[item.id]!, 'error');
        }
      }
    });
    return table == 'brews' && rejections.isNotEmpty;
  }

  Future<bool> _markIfUnchanged(
    Transaction txn,
    String table,
    String userId,
    Map<String, Object?> sent,
    String status,
  ) async {
    final current = await txn.query(
      table,
      where: 'id = ? AND user_id = ?',
      whereArgs: [sent['id'], userId],
      limit: 1,
    );
    if (current.isEmpty ||
        current.single.length != sent.length ||
        sent.entries.any((entry) => current.single[entry.key] != entry.value)) {
      return false;
    }
    await txn.update(
      table,
      {'sync_status': status},
      where: 'id = ? AND user_id = ?',
      whereArgs: [sent['id'], userId],
    );
    return true;
  }

  Future<void> _saveSummary(
    String userId,
    Map<String, int> accepted,
    Map<String, int> rejected,
  ) async {
    final now = DateTime.now().toUtc().toIso8601String().replaceFirst(
      RegExp(r'\.\d+Z$'),
      'Z',
    );
    await _database.transaction((txn) async {
      for (final entry in {
        'last_sync_at': now,
        'last_sync_summary': jsonEncode({
          'accepted': accepted,
          'rejected': rejected,
        }),
      }.entries) {
        await txn.insert('settings', {
          'user_id': userId,
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}
