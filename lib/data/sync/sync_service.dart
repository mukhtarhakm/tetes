import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/utils/hash.dart';
import '../repositories/event_repo.dart';
import '../remote/sync_client.dart';

typedef SyncUnauthorized = Future<void> Function();
typedef SyncEventChanged = Future<void> Function(String userId, int? oldBaseId);
typedef SyncBrewsAccepted = Future<void> Function(String userId);

class SyncStatus {
  const SyncStatus({
    required this.pendingCount,
    required this.errorCount,
    this.lastSyncAt,
    this.summary,
    this.lastPullAt,
    this.pullSummary,
  });

  final int pendingCount;
  final int errorCount;
  final String? lastSyncAt;
  final Map<String, dynamic>? summary;
  final String? lastPullAt;
  final Map<String, dynamic>? pullSummary;
}

class SyncService {
  SyncService(
    this._database,
    this._client,
    this._onUnauthorized, [
    this._onEventChanged,
    this._onBrewsAccepted,
  ]);

  final Database _database;
  final SyncClient _client;
  final SyncUnauthorized _onUnauthorized;
  final SyncEventChanged? _onEventChanged;
  final SyncBrewsAccepted? _onBrewsAccepted;
  bool _running = false;

  void close() => _client.close();

  static const reasonMessages = <String, String>{
    'invalid': 'Data tidak valid.',
    'invalid_event':
        'Event tidak valid. Periksa nama, jenis, zona, pengingat, dan waktu.',
    'invalid_score':
        'Skor game tidak valid. Periksa level, akurasi, bintang, dan durasi.',
    'invalid_feedback':
        'Saran atau kesan tidak valid. Isi salah satu, maksimal 500 karakter.',
    'future_timestamp':
        'Waktu pencatatan lebih dari 5 menit di masa depan. Periksa jam HP.',
    'hash_mismatch': 'Hash seduhan tidak cocok.',
    'chain_broken': 'Urutan rantai seduhan terputus.',
    'tamper': 'Data seduhan berbeda dari yang tersimpan di server.',
    'not_owner': 'Data ini bukan milik akun yang sedang masuk.',
    'chain_blocked': 'Seduhan menunggu perbaikan entri sebelumnya.',
    'immutable': 'Data yang sudah tersimpan tidak boleh diubah.',
    'stale':
        'Event di server lebih baru. Tarik data dari server atau ubah lagi event ini.',
  };

  Future<SyncStatus> status(String userId) async {
    final counts = await _database.rawQuery('''
      SELECT (SELECT COUNT(*) FROM beans WHERE user_id = ? AND sync_status = 'pending') +
             (SELECT COUNT(*) FROM brews WHERE user_id = ? AND sync_status = 'pending') +
             (SELECT COUNT(*) FROM events WHERE user_id = ? AND sync_status = 'pending') +
             (SELECT COUNT(*) FROM game_scores WHERE user_id = ? AND sync_status = 'pending') +
             (SELECT COUNT(*) FROM feedback WHERE user_id = ? AND sync_status = 'pending') AS pending_count,
             (SELECT COUNT(*) FROM beans WHERE user_id = ? AND sync_status = 'error') +
             (SELECT COUNT(*) FROM brews WHERE user_id = ? AND sync_status = 'error') +
             (SELECT COUNT(*) FROM events WHERE user_id = ? AND sync_status = 'error') +
             (SELECT COUNT(*) FROM game_scores WHERE user_id = ? AND sync_status = 'error') +
             (SELECT COUNT(*) FROM feedback WHERE user_id = ? AND sync_status = 'error') AS error_count
    ''', List.filled(10, userId));
    final settings = await _database.query(
      'settings',
      columns: ['key', 'value'],
      where: 'user_id = ? AND key IN (?, ?, ?, ?)',
      whereArgs: [
        userId,
        'last_sync_at',
        'last_sync_summary',
        'last_pull_at',
        'last_pull_summary',
      ],
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
    Map<String, dynamic>? pullSummary;
    try {
      final decoded = jsonDecode(values['last_pull_summary'] ?? '');
      if (decoded is Map<String, dynamic>) pullSummary = decoded;
    } on FormatException {
      // Ringkasan rusak tidak menghalangi sinkronisasi.
    }
    return SyncStatus(
      pendingCount: (counts.single['pending_count'] as num).toInt(),
      errorCount: (counts.single['error_count'] as num).toInt(),
      lastSyncAt: values['last_sync_at'],
      summary: summary,
      lastPullAt: values['last_pull_at'],
      pullSummary: pullSummary,
    );
  }

  Future<SyncStatus> pull(String userId) async {
    if (_running) {
      throw const SyncException(
        SyncFailure.badRequest,
        'Sinkronisasi sedang berjalan.',
      );
    }
    _running = true;
    var beanCount = 0;
    var brewCount = 0;
    String? lastStatus;
    final changedBeans = <String>{};
    try {
      final local = await _database.query(
        'brews',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'seq ASC',
      );
      if (!verifyChain(local.map(_chainEntry)).startsWith('utuh')) {
        throw const SyncException(
          SyncFailure.badRequest,
          'Rantai seduhan di HP tidak lolos verifikasi.',
        );
      }
      final chain = [...local];
      while (true) {
        final last = chain.isEmpty ? null : chain.last;
        final page = await _pull(
          userId,
          last == null ? 0 : last['seq'] as int,
          last?['hash'] as String?,
        );
        lastStatus = page.status;
        if (page.status == 'diverged') {
          throw SyncException(
            SyncFailure.badRequest,
            'Data di HP dan server tidak cocok (seq terakhir server: ${page.serverLastSeq}).',
          );
        }
        if (page.status == 'local_ahead' || page.status == 'up_to_date') break;
        if (page.status == 'empty_server' && page.brews.isNotEmpty ||
            page.status == 'pull' && page.brews.isEmpty) {
          throw const SyncException(
            SyncFailure.server,
            'Respons tarik data tidak valid. Coba lagi.',
          );
        }
        final incoming = page.brews.map(_brewRow).toList();
        if (page.status == 'pull' &&
            !verifyChain(
              [...chain, ...incoming].map(_chainEntry),
            ).startsWith('utuh')) {
          throw const SyncException(
            SyncFailure.server,
            'Data dari server tidak lolos verifikasi.',
          );
        }
        final inserted = await _database.transaction((txn) async {
          var addedBeans = 0;
          for (final bean in page.beans) {
            final row = _beanRow(bean, userId);
            final existing = await txn.query(
              'beans',
              columns: ['user_id'],
              where: 'id = ?',
              whereArgs: [row['id']],
              limit: 1,
            );
            if (existing.isNotEmpty) {
              if (existing.single['user_id'] != userId) {
                throw const FormatException('bean owner');
              }
              continue;
            }
            await txn.insert('beans', row);
            addedBeans++;
          }
          for (var i = 0; i < incoming.length; i++) {
            final row = {
              ...incoming[i],
              'user_id': userId,
              'sync_status': 'synced',
            };
            await txn.insert('brews', row);
            changedBeans.add(row['bean_id'] as String);
            for (final stage in _stageRows(
              page.brews[i]['stages'],
              row['id'] as String,
            )) {
              await txn.insert('brew_stages', stage);
            }
          }
          return addedBeans;
        });
        beanCount += inserted;
        brewCount += incoming.length;
        chain.addAll(incoming);
        if (!page.hasMore) break;
      }
      await _updateBestBrews(userId, changedBeans);
      SyncException? groupError;
      for (final group in const ['events', 'game_scores', 'feedback']) {
        try {
          await _pullGroup(userId, group);
        } on SyncException catch (error) {
          if (error.failure == SyncFailure.unauthorized) {
            await _onUnauthorized();
            rethrow;
          }
          groupError ??= error;
        } catch (_) {
          groupError ??= const SyncException(
            SyncFailure.server,
            'Data dari server tidak valid. Coba lagi.',
          );
        }
      }
      if (groupError != null) throw groupError;
      await _savePullSummary(userId, beanCount, brewCount, null, lastStatus);
      return status(userId);
    } on SyncException catch (error) {
      await _savePullSummary(userId, beanCount, brewCount, error.message);
      rethrow;
    } catch (_) {
      const error = SyncException(
        SyncFailure.server,
        'Tarik data gagal. Coba lagi.',
      );
      await _savePullSummary(userId, beanCount, brewCount, error.message);
      throw error;
    } finally {
      _running = false;
    }
  }

  Future<void> _pullGroup(String userId, String group) async {
    String? cursorAt;
    String? cursorId;
    do {
      final page = await _client.pullGroup(
        userId: userId,
        group: group,
        cursorAt: cursorAt,
        cursorId: cursorId,
      );
      if (page.hasMore &&
          (page.cursorAt == cursorAt && page.cursorId == cursorId)) {
        throw const SyncException(
          SyncFailure.server,
          'Halaman sinkronisasi tidak bergerak. Coba lagi.',
        );
      }
      final changedBases = <int?>[];
      await _database.transaction((txn) async {
        for (final value in page.rows) {
          final id = value['id'];
          if (id is! String) throw const FormatException('id');
          final existing = await txn.query(
            group,
            where: 'id = ?',
            whereArgs: [id],
            limit: 1,
          );
          if (existing.isNotEmpty && existing.single['user_id'] != userId) {
            throw const FormatException('owner');
          }
          if (group == 'events') {
            final updated = value['updated_at'];
            if (updated is! String ||
                value['deleted'] is! bool ||
                value['name'] is! String ||
                value['start_utc'] is! String ||
                value['source_zone'] is! String ||
                value['reminder_minutes'] is! String ||
                value['created_at'] is! String) {
              throw const FormatException('event');
            }
            if (existing.isNotEmpty &&
                (existing.single['sync_status'] == 'pending' ||
                    (existing.single['updated_at'] as String).compareTo(
                          updated,
                        ) >=
                        0)) {
              continue;
            }
            final row = Map<String, Object?>.from(value)
              ..remove('server_updated_at')
              ..['user_id'] = userId
              ..['deleted'] = value['deleted'] == true ? 1 : 0
              ..['sync_status'] = 'synced'
              ..['notif_base_id'] = existing.isEmpty
                  ? null
                  : existing.single['notif_base_id'];
            if (existing.isEmpty) {
              await txn.insert(group, row);
            } else {
              await txn.update(
                group,
                row,
                where: 'id = ? AND user_id = ?',
                whereArgs: [id, userId],
              );
            }
            changedBases.add(
              existing.isEmpty
                  ? null
                  : existing.single['notif_base_id'] as int?,
            );
          } else {
            if (existing.isNotEmpty) continue;
            final row = Map<String, Object?>.from(value)
              ..remove('server_updated_at')
              ..['user_id'] = userId
              ..['sync_status'] = 'synced';
            await txn.insert(group, row);
          }
        }
      });
      if (group == 'events' && changedBases.isNotEmpty) {
        await EventRepository(
          _database,
        ).assignPulledNotificationBaseIds(userId);
        for (final base in changedBases) {
          await _onEventChanged?.call(userId, base);
        }
      }
      cursorAt = page.cursorAt;
      cursorId = page.cursorId;
      if (!page.hasMore) break;
    } while (true);
  }

  Future<SyncPullResponse> _pull(String userId, int seq, String? hash) async {
    try {
      return await _client.pullData(
        userId: userId,
        lastSeq: seq,
        lastHash: hash,
      );
    } on SyncException catch (error) {
      if (error.failure == SyncFailure.unauthorized) await _onUnauthorized();
      rethrow;
    }
  }

  BrewChainEntry _chainEntry(Map<String, Object?> row) => (
    seq: row['seq'] as int,
    data: (
      beanId: row['bean_id'] as String,
      doseG: (row['dose_g'] as num).toDouble(),
      ratio: (row['ratio'] as num).toDouble(),
      waterTempC: row['water_temp_c'] as int,
      grind: row['grind'] as String,
      totalTimeS: row['total_time_s'] as int,
      tasteScore: row['taste_score'] as int,
      tasteTags: (row['taste_tags'] as String).split(','),
      brewedAtUtc: row['brewed_at_utc'] as String,
    ),
    prevHash: row['prev_hash'] as String,
    hash: row['hash'] as String,
    status: row['status'] as String,
  );

  static const _beanColumns =
      'id name species bean_type arabica_percent roastery is_self_roasted origin process process_custom roast_level roast_date pack_size_g price_original currency fx_rate fx_date price_idr_per_kg initial_stock_g roastery_notes_tags roastery_notes_text best_brew_id archived created_at updated_at';
  static const _brewColumns =
      'id seq bean_id brewed_at_utc dose_g ratio water_temp_c grind total_time_s taste_score taste_tags notes ai_advice cost_idr status prev_hash hash created_at';
  static const _stageColumns =
      'id brew_id position name target_start_s target_duration_s target_water_cum_g target_pour_g actual_start_s actual_duration_s actual_water_g drawdown_s';

  Map<String, Object?> _beanRow(Map<String, dynamic> value, String userId) {
    final row = {for (final key in _beanColumns.split(' ')) key: value[key]};
    if (row['id'] is! String ||
        row['name'] is! String ||
        row['species'] is! String ||
        row['created_at'] is! String ||
        row['updated_at'] is! String ||
        row['is_self_roasted'] is! bool ||
        row['archived'] is! bool ||
        row['initial_stock_g'] is! num) {
      throw const FormatException('bean');
    }
    row['is_self_roasted'] = row['is_self_roasted'] == true ? 1 : 0;
    row['archived'] = row['archived'] == true ? 1 : 0;
    return {...row, 'user_id': userId, 'sync_status': 'synced'};
  }

  Map<String, Object?> _brewRow(Map<String, dynamic> value) {
    final row = {for (final key in _brewColumns.split(' ')) key: value[key]};
    if (row['id'] is! String ||
        row['seq'] is! int ||
        row['bean_id'] is! String ||
        row['brewed_at_utc'] is! String ||
        !RegExp(
          r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$',
        ).hasMatch(row['brewed_at_utc'] as String) ||
        row['dose_g'] is! num ||
        row['ratio'] is! num ||
        row['water_temp_c'] is! int ||
        row['grind'] is! String ||
        row['total_time_s'] is! int ||
        row['taste_score'] is! int ||
        row['taste_tags'] is! String ||
        row['prev_hash'] is! String ||
        row['hash'] is! String ||
        row['status'] is! String ||
        row['created_at'] is! String) {
      throw const SyncException(
        SyncFailure.server,
        'Data dari server tidak lolos verifikasi.',
      );
    }
    return row;
  }

  List<Map<String, Object?>> _stageRows(Object? value, String brewId) {
    if (value is! List || value.isEmpty || value.length > 5) {
      throw const FormatException('stages');
    }
    final rows = <Map<String, Object?>>[];
    for (var i = 0; i < value.length; i++) {
      final stage = value[i];
      if (stage is! Map<String, dynamic>) throw const FormatException('stage');
      final row = {for (final key in _stageColumns.split(' ')) key: stage[key]};
      if (row['id'] is! String ||
          row['brew_id'] != brewId ||
          row['position'] != i + 1 ||
          row['name'] is! String ||
          row['target_start_s'] is! int ||
          row['target_duration_s'] is! int ||
          row['target_water_cum_g'] is! num ||
          row['target_pour_g'] is! num) {
        throw const FormatException('stage');
      }
      rows.add(row);
    }
    return rows;
  }

  Future<void> _updateBestBrews(String userId, Set<String> beanIds) async {
    if (beanIds.isEmpty) return;
    final now = DateTime.now().toUtc().toIso8601String().replaceFirst(
      RegExp(r'\.\d+Z$'),
      'Z',
    );
    await _database.transaction((txn) async {
      for (final beanId in beanIds) {
        final best = await txn.query(
          'brews',
          columns: ['id'],
          where: 'user_id = ? AND bean_id = ? AND status = ?',
          whereArgs: [userId, beanId, 'aktif'],
          orderBy: 'taste_score DESC, brewed_at_utc DESC, seq DESC',
          limit: 1,
        );
        final bean = await txn.query(
          'beans',
          columns: ['best_brew_id'],
          where: 'id = ? AND user_id = ?',
          whereArgs: [beanId, userId],
          limit: 1,
        );
        if (bean.isNotEmpty &&
            bean.single['best_brew_id'] !=
                (best.isEmpty ? null : best.single['id'])) {
          await txn.update(
            'beans',
            {
              'best_brew_id': best.isEmpty ? null : best.single['id'],
              'updated_at': now,
              'sync_status': 'pending',
            },
            where: 'id = ? AND user_id = ?',
            whereArgs: [beanId, userId],
          );
        }
      }
    });
  }

  Future<void> _savePullSummary(
    String userId,
    int beans,
    int brews, [
    String? error,
    String? status,
  ]) async {
    final now = DateTime.now().toUtc().toIso8601String().replaceFirst(
      RegExp(r'\.\d+Z$'),
      'Z',
    );
    await _database.transaction((txn) async {
      for (final item in {
        'last_pull_at': now,
        'last_pull_summary': jsonEncode({
          'beans': beans,
          'brews': brews,
          'error': ?error,
          'status': ?status,
        }),
      }.entries) {
        await txn.insert('settings', {
          'user_id': userId,
          'key': item.key,
          'value': item.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
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
    final acceptedCounts = {
      'beans': 0,
      'brews': 0,
      'events': 0,
      'game_scores': 0,
      'feedback': 0,
    };
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
      if (acceptedCounts['brews']! > 0 && _onBrewsAccepted != null) {
        unawaited(() async {
          try {
            await _onBrewsAccepted(userId);
          } catch (_) {
            // Kegagalan jangkar tidak membatalkan sinkronisasi seduhan.
          }
        }());
      }
      SyncException? groupError;
      for (final group in const ['events', 'game_scores', 'feedback']) {
        try {
          final rows = await _pendingRows(
            group,
            userId,
            states,
            group == 'events'
                ? 'updated_at ASC, id ASC'
                : group == 'game_scores'
                ? 'played_at ASC, id ASC'
                : 'created_at ASC, id ASC',
          );
          for (var start = 0; start < rows.length; start += 100) {
            final batch = rows.skip(start).take(100).toList();
            final payload = batch.map((row) {
              final json = Map<String, Object?>.of(row)
                ..remove('user_id')
                ..remove('sync_status')
                ..remove('notif_base_id');
              if (group == 'events') json['deleted'] = row['deleted'] == 1;
              return json;
            }).toList();
            final response = await _client.pushGroup(
              userId: userId,
              group: group,
              rows: payload,
            );
            await _apply(
              group,
              userId,
              batch,
              response,
              acceptedCounts,
              rejectedCounts,
            );
            await _saveSummary(userId, acceptedCounts, rejectedCounts);
          }
        } on SyncException catch (error) {
          if (error.failure == SyncFailure.unauthorized) {
            await _onUnauthorized();
            rethrow;
          }
          rejectedCounts['${group}_request'] =
              (rejectedCounts['${group}_request'] ?? 0) + 1;
          groupError ??= error;
        } catch (_) {
          rejectedCounts['${group}_request'] =
              (rejectedCounts['${group}_request'] ?? 0) + 1;
          groupError ??= const SyncException(
            SyncFailure.server,
            'Sinkronisasi kelompok data gagal. Coba lagi.',
          );
        }
      }
      if (groupError != null) {
        await _saveSummary(userId, acceptedCounts, rejectedCounts);
        throw groupError;
      }
      if ((rejectedCounts['stale'] ?? 0) > 0) {
        await _pullGroup(userId, 'events');
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
