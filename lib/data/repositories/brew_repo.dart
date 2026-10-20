import 'package:sqflite/sqflite.dart';

import '../../core/utils/hash.dart';
import '../../core/utils/uuid_v4.dart';
import '../../features/beans/bean_model.dart';
import '../../features/brew/brew_calculator.dart';
import '../../features/brew/brew_plan.dart';
import '../../features/brew/brew_session_result.dart';
import '../../features/journal/journal_model.dart';

class BrewSaveException implements Exception {
  const BrewSaveException(this.message);
  final String message;
}

double? brewCost(double doseG, double? priceIdrPerKg) =>
    priceIdrPerKg == null ? null : doseG * priceIdrPerKg / 1000;

String escapeSqlLike(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

class BrewRepository {
  const BrewRepository(this._database);

  final Database _database;

  Future<String> save({
    required String userId,
    required BrewSessionResult result,
    required int tasteScore,
    required Iterable<RoasteryNoteTag> tasteTags,
    required List<double?> actualWaterG,
    int? drawdownS,
    String? notes,
  }) async {
    final plan = result.plan;
    final tags = tasteTags.map((tag) => tag.databaseValue).toSet().toList()
      ..sort();
    if (tasteScore < 1 ||
        tasteScore > 5 ||
        tags.isEmpty ||
        actualWaterG.length != plan.stages.length ||
        actualWaterG.any(
          (value) => value != null && (!value.isFinite || value < 0),
        ) ||
        (drawdownS != null && drawdownS < 0)) {
      throw const BrewSaveException('Data hasil seduh belum valid.');
    }
    final id = createUuidV4();
    final now = DateTime.now().toUtc().toIso8601String().replaceFirst(
      RegExp(r'\.\d+Z$'),
      'Z',
    );
    try {
      await _database.transaction((txn) async {
        final beans = await txn.query(
          'beans',
          columns: ['price_idr_per_kg'],
          where: 'id = ? AND user_id = ? AND archived = 0',
          whereArgs: [plan.beanId, userId],
          limit: 1,
        );
        if (beans.isEmpty) {
          throw const BrewSaveException(
            'Biji tidak ditemukan atau sudah diarsipkan.',
          );
        }
        final last = await txn.query(
          'brews',
          columns: ['seq', 'hash'],
          where: 'user_id = ?',
          whereArgs: [userId],
          orderBy: 'seq DESC',
          limit: 1,
        );
        final seq = last.isEmpty ? 1 : (last.single['seq'] as num).toInt() + 1;
        final prevHash = last.isEmpty ? '0' : last.single['hash'] as String;
        final row = <String, Object?>{
          'id': id,
          'user_id': userId,
          'seq': seq,
          'bean_id': plan.beanId,
          'brewed_at_utc': result.brewedAtUtc,
          'dose_g': plan.doseG,
          'ratio': plan.ratio,
          'water_temp_c': plan.waterTempC,
          'grind': plan.grind.databaseValue,
          'total_time_s': result.totalTimeS,
          'taste_score': tasteScore,
          'taste_tags': tags.join(','),
          'cost_idr': brewCost(
            plan.doseG,
            (beans.single['price_idr_per_kg'] as num?)?.toDouble(),
          ),
          'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
          'ai_advice': null,
          'status': 'aktif',
          'sync_status': 'pending',
          'created_at': now,
          'prev_hash': prevHash,
        };
        final data = _hashData(row);
        row['hash'] = hashEntry(data, prevHash);
        await txn.insert('brews', row);
        for (var index = 0; index < plan.stages.length; index++) {
          final stage = plan.stages[index];
          await txn.insert('brew_stages', {
            'id': createUuidV4(),
            'brew_id': id,
            'position': stage.position,
            'name': stage.name.databaseValue,
            'target_start_s': stage.startSeconds,
            'target_duration_s': stage.durationSeconds,
            'target_water_cum_g': plan.cumulativeWaterAt(index),
            'target_pour_g': stage.targetPourG,
            'actual_water_g': actualWaterG[index],
            'actual_start_s': null,
            'actual_duration_s': null,
            'drawdown_s': index == plan.stages.length - 1 ? drawdownS : null,
          });
        }
        final best = await txn.query(
          'brews',
          columns: ['id'],
          where: 'user_id = ? AND bean_id = ? AND status = ?',
          whereArgs: [userId, plan.beanId, 'aktif'],
          orderBy: 'taste_score DESC, brewed_at_utc DESC, seq DESC',
          limit: 1,
        );
        await txn.update(
          'beans',
          {
            'best_brew_id': best.single['id'],
            'updated_at': now,
            'sync_status': 'pending',
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [plan.beanId, userId],
        );
      });
    } on BrewSaveException {
      rethrow;
    } on DatabaseException {
      throw const BrewSaveException('Seduhan gagal disimpan. Coba lagi.');
    }
    return id;
  }

  Future<String> verifyUserChain(String userId) async {
    final rows = await _database.query(
      'brews',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'seq ASC',
    );
    return verifyChain(
      rows.map(
        (row) => (
          seq: (row['seq'] as num).toInt(),
          data: _hashData(row),
          prevHash: row['prev_hash'] as String,
          hash: row['hash'] as String,
          status: row['status'] as String,
        ),
      ),
    );
  }

  Future<double> remainingStockG({
    required String userId,
    required String beanId,
  }) async {
    final rows = await _database.rawQuery(
      '''
      SELECT b.initial_stock_g - COALESCE(SUM(CASE WHEN br.status = 'aktif' THEN br.dose_g ELSE 0 END), 0) AS remaining
      FROM beans b LEFT JOIN brews br ON br.bean_id = b.id
      WHERE b.user_id = ? AND b.id = ? GROUP BY b.id
    ''',
      [userId, beanId],
    );
    if (rows.isEmpty) throw const BrewSaveException('Biji tidak ditemukan.');
    return (rows.single['remaining'] as num).toDouble();
  }

  Future<bool> isLowStock({
    required String userId,
    required String beanId,
  }) async {
    final remaining = await remainingStockG(userId: userId, beanId: beanId);
    final rows = await _database.query(
      'settings',
      columns: ['value'],
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, 'low_stock_threshold_g'],
      limit: 1,
    );
    final threshold = rows.isEmpty
        ? null
        : double.tryParse(rows.single['value'] as String);
    return remaining < (threshold ?? BeanDefaults.lowStockThresholdG);
  }

  BrewHashData _hashData(Map<String, Object?> row) => (
    beanId: row['bean_id'] as String,
    doseG: (row['dose_g'] as num).toDouble(),
    ratio: (row['ratio'] as num).toDouble(),
    waterTempC: (row['water_temp_c'] as num).toInt(),
    grind: row['grind'] as String,
    totalTimeS: (row['total_time_s'] as num).toInt(),
    tasteScore: (row['taste_score'] as num).toInt(),
    tasteTags: (row['taste_tags'] as String).split(','),
    brewedAtUtc: row['brewed_at_utc'] as String,
  );

  Future<BrewPlan?> findBestPlan({
    required String userId,
    required String beanId,
    required String bestBrewId,
  }) async {
    final brewRows = await _database.query(
      'brews',
      columns: ['id', 'dose_g', 'ratio', 'water_temp_c', 'grind'],
      where: 'id = ? AND user_id = ? AND bean_id = ? AND status = ?',
      whereArgs: [bestBrewId, userId, beanId, 'aktif'],
      limit: 1,
    );
    if (brewRows.isEmpty) {
      return null;
    }

    final stageRows = await _database.query(
      'brew_stages',
      columns: [
        'position',
        'name',
        'target_start_s',
        'target_duration_s',
        'target_water_cum_g',
        'target_pour_g',
      ],
      where: 'brew_id = ?',
      whereArgs: [bestBrewId],
      orderBy: 'position ASC',
    );

    try {
      final row = brewRows.single;
      final grind = Grind.tryFromDatabase(row['grind']! as String);
      if (grind == null || stageRows.isEmpty || stageRows.length > 5) {
        return null;
      }
      final stages = <BrewStage>[];
      var cumulativeWater = 0.0;
      for (var index = 0; index < stageRows.length; index++) {
        final stageRow = stageRows[index];
        final position = (stageRow['position']! as num).toInt();
        final name = BrewStageName.tryFromDatabase(stageRow['name']! as String);
        if (name == null) {
          return null;
        }
        final duration = (stageRow['target_duration_s']! as num).toInt();
        final start = (stageRow['target_start_s']! as num).toInt();
        final targetPour = (stageRow['target_pour_g']! as num).toDouble();
        cumulativeWater += targetPour;
        final storedCumulative = (stageRow['target_water_cum_g']! as num)
            .toDouble();
        if ((storedCumulative - cumulativeWater).abs() > 0.000001) {
          return null;
        }
        stages.add(
          BrewStage(
            position: position,
            name: name,
            startSeconds: start,
            durationSeconds: duration,
            targetPourG: targetPour,
          ),
        );
      }

      final plan = BrewPlan(
        beanId: beanId,
        doseG: (row['dose_g']! as num).toDouble(),
        ratio: (row['ratio']! as num).toDouble(),
        waterTempC: (row['water_temp_c']! as num).toInt(),
        grind: grind,
        pouringCount: stages.length,
        stages: List.unmodifiable(stages),
        fromBestBrew: true,
      );
      BrewCalculator.validatePlan(plan);
      return plan;
    } on BrewPlanException {
      return null;
    } on FormatException {
      return null;
    } on StateError {
      return null;
    } on TypeError {
      return null;
    }
  }

  /// Aturan pencarian dan filter jurnal seduhan:
  /// 1. Selalu dibatasi user_id aktif dengan parameter terikat.
  /// 2. Entri dibatalkan disembunyikan secara bawaan kecuali includeCancelled = true.
  /// 3. Pencarian satu kolom (nama biji, roastery, tag rasa, catatan) meng-escape '%' dan '_' dengan ESCAPE '\'.
  /// 4. Filter biji: mencocokkan salah satu dari biji yang dipilih (OR / IN).
  /// 5. Filter tag: entri yang memuat salah satu tag terpilih (tag utuh):
  ///    (',' || br.taste_tags || ',') LIKE '%,tag,%' ESCAPE '\'.
  /// 6. Rentang tanggal: batas dihitung dari waktu lokal lalu diubah ke UTC ISO 8601 string.
  ///    Rentang tanggal kustom inklusif sampai akhir hari (23:59:59 lokal -> UTC).
  /// 7. Semua urutan diakhiri seq DESC sebagai pemutus seri, dan cost_idr kosong selalu di akhir pada pengurutan biaya.
  Future<List<BrewJournalItem>> findJournalBrews({
    required String userId,
    String? searchQuery,
    Set<String>? beanIds,
    int? minTasteScore,
    Set<String>? tasteTags,
    String? startBrewedAtUtc,
    String? endBrewedAtUtc,
    BrewSortOption sortOption = BrewSortOption.newest,
    bool includeCancelled = false,
  }) async {
    final whereClauses = <String>['br.user_id = ?'];
    final whereArgs = <Object?>[userId];

    if (!includeCancelled) {
      whereClauses.add("br.status = 'aktif'");
    }

    final trimmedSearch = searchQuery?.trim();
    if (trimmedSearch != null && trimmedSearch.isNotEmpty) {
      final escaped = escapeSqlLike(trimmedSearch);
      final pattern = '%$escaped%';
      whereClauses.add('''
        (
          b.name LIKE ? ESCAPE '\\' OR
          (b.roastery IS NOT NULL AND b.roastery LIKE ? ESCAPE '\\') OR
          br.taste_tags LIKE ? ESCAPE '\\' OR
          (br.notes IS NOT NULL AND br.notes LIKE ? ESCAPE '\\')
        )
      ''');
      whereArgs.addAll([pattern, pattern, pattern, pattern]);
    }

    // Filter biji: salah satu dari yang dipilih (OR)
    if (beanIds != null && beanIds.isNotEmpty) {
      final placeholders = List.filled(beanIds.length, '?').join(', ');
      whereClauses.add('br.bean_id IN ($placeholders)');
      whereArgs.addAll(beanIds);
    }

    // Filter skor minimal
    if (minTasteScore != null) {
      whereClauses.add('br.taste_score >= ?');
      whereArgs.add(minTasteScore);
    }

    // Filter tag: entri yang memuat salah satu tag terpilih (tag utuh)
    if (tasteTags != null && tasteTags.isNotEmpty) {
      final tagConditions = <String>[];
      for (final tag in tasteTags) {
        final escaped = escapeSqlLike(tag);
        tagConditions.add("(',' || br.taste_tags || ',') LIKE ? ESCAPE '\\'");
        whereArgs.add('%,$escaped,%');
      }
      whereClauses.add('(${tagConditions.join(' OR ')})');
    }

    // Rentang tanggal kustom inklusif sampai akhir hari (diubah ke UTC)
    if (startBrewedAtUtc != null) {
      whereClauses.add('br.brewed_at_utc >= ?');
      whereArgs.add(startBrewedAtUtc);
    }
    if (endBrewedAtUtc != null) {
      whereClauses.add('br.brewed_at_utc <= ?');
      whereArgs.add(endBrewedAtUtc);
    }

    // Semua urutan diakhiri seq DESC sebagai pemutus seri, dan cost_idr kosong selalu di akhir
    final orderBy = switch (sortOption) {
      BrewSortOption.newest =>
        'br.brewed_at_utc DESC, br.seq DESC',
      BrewSortOption.highestScore =>
        'br.taste_score DESC, br.brewed_at_utc DESC, br.seq DESC',
      BrewSortOption.cost =>
        '(CASE WHEN br.cost_idr IS NULL THEN 1 ELSE 0 END) ASC, br.cost_idr DESC, br.brewed_at_utc DESC, br.seq DESC',
    };

    final whereString = whereClauses.join(' AND ');
    final query = '''
      SELECT
        br.*,
        b.name AS bean_name,
        b.roastery AS bean_roastery,
        CASE WHEN b.best_brew_id = br.id THEN 1 ELSE 0 END AS is_best_brew
      FROM brews br
      JOIN beans b ON br.bean_id = b.id
      WHERE $whereString
      ORDER BY $orderBy
    ''';

    final rows = await _database.rawQuery(query, whereArgs);
    return rows.map((row) {
      final grind =
          Grind.tryFromDatabase(row['grind'] as String) ?? Grind.sedang;
      final tags = (row['taste_tags'] as String?)
              ?.split(',')
              .where((t) => t.isNotEmpty)
              .toList() ??
          <String>[];
      return BrewJournalItem(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        seq: (row['seq'] as num).toInt(),
        beanId: row['bean_id'] as String,
        beanName: row['bean_name'] as String,
        beanRoastery: row['bean_roastery'] as String?,
        isBestBrew: (row['is_best_brew'] as num).toInt() == 1,
        brewedAtUtc: row['brewed_at_utc'] as String,
        doseG: (row['dose_g'] as num).toDouble(),
        ratio: (row['ratio'] as num).toDouble(),
        waterTempC: (row['water_temp_c'] as num).toInt(),
        grind: grind,
        totalTimeS: (row['total_time_s'] as num).toInt(),
        tasteScore: (row['taste_score'] as num).toInt(),
        tasteTags: tags,
        costIdr: (row['cost_idr'] as num?)?.toDouble(),
        status: row['status'] as String,
        syncStatus: row['sync_status'] as String,
        hash: row['hash'] as String,
      );
    }).toList();
  }

  Future<BrewDetailData?> findBrewDetail({
    required String userId,
    required String brewId,
  }) async {
    final brewRows = await _database.rawQuery(
      '''
      SELECT
        br.*,
        b.name AS bean_name,
        b.roastery AS bean_roastery,
        b.roastery_notes_tags AS bean_notes_tags,
        b.roastery_notes_text AS bean_notes_text,
        b.archived AS bean_archived,
        CASE WHEN b.best_brew_id = br.id THEN 1 ELSE 0 END AS is_best_brew
      FROM brews br
      JOIN beans b ON br.bean_id = b.id
      WHERE br.id = ? AND br.user_id = ?
      LIMIT 1
    ''',
      [brewId, userId],
    );

    if (brewRows.isEmpty) {
      return null;
    }
    final row = brewRows.single;
    final grind = Grind.tryFromDatabase(row['grind'] as String) ?? Grind.sedang;
    final tasteTags = (row['taste_tags'] as String?)
            ?.split(',')
            .where((t) => t.isNotEmpty)
            .toList() ??
        <String>[];
    final roasteryTags = (row['bean_notes_tags'] as String?)
            ?.split(',')
            .where((t) => t.isNotEmpty)
            .toList() ??
        <String>[];

    final item = BrewJournalItem(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      seq: (row['seq'] as num).toInt(),
      beanId: row['bean_id'] as String,
      beanName: row['bean_name'] as String,
      beanRoastery: row['bean_roastery'] as String?,
      isBestBrew: (row['is_best_brew'] as num).toInt() == 1,
      brewedAtUtc: row['brewed_at_utc'] as String,
      doseG: (row['dose_g'] as num).toDouble(),
      ratio: (row['ratio'] as num).toDouble(),
      waterTempC: (row['water_temp_c'] as num).toInt(),
      grind: grind,
      totalTimeS: (row['total_time_s'] as num).toInt(),
      tasteScore: (row['taste_score'] as num).toInt(),
      tasteTags: tasteTags,
      costIdr: (row['cost_idr'] as num?)?.toDouble(),
      status: row['status'] as String,
      syncStatus: row['sync_status'] as String,
      hash: row['hash'] as String,
    );

    final stageRows = await _database.query(
      'brew_stages',
      where: 'brew_id = ?',
      whereArgs: [brewId],
      orderBy: 'position ASC',
    );

    final stages = stageRows.map((stageRow) {
      return BrewDetailStage(
        id: stageRow['id'] as String,
        brewId: stageRow['brew_id'] as String,
        position: (stageRow['position'] as num).toInt(),
        name: BrewStageName.tryFromDatabase(stageRow['name'] as String) ??
            BrewStageName.bloom,
        targetStartS: (stageRow['target_start_s'] as num).toInt(),
        targetDurationS: (stageRow['target_duration_s'] as num).toInt(),
        targetWaterCumG: (stageRow['target_water_cum_g'] as num).toDouble(),
        targetPourG: (stageRow['target_pour_g'] as num).toDouble(),
        actualWaterG: (stageRow['actual_water_g'] as num?)?.toDouble(),
        drawdownS: (stageRow['drawdown_s'] as num?)?.toInt(),
      );
    }).toList();

    return BrewDetailData(
      item: item,
      notes: row['notes'] as String?,
      aiAdvice: row['ai_advice'] as String?,
      prevHash: row['prev_hash'] as String,
      createdAt: row['created_at'] as String,
      roasteryNotesTags: roasteryTags,
      roasteryNotesText: row['bean_notes_text'] as String?,
      isBeanArchived: (row['bean_archived'] as num).toInt() == 1,
      stages: stages,
    );
  }

  /// Membatalkan seduhan dalam satu transaksi:
  /// - Hanya untuk entri milik userId aktif yang berstatus 'aktif'.
  /// - Mengubah status='dibatalkan' dan sync_status='pending'.
  /// - DILARANG menyentuh hash, prev_hash, seq, atau field yang di-hash.
  /// - Menghitung ulang best_brew_id biji dari seduhan aktif milik userId (skor tertinggi, seri dimenangkan yang terbaru).
  /// - Memperbarui best_brew_id (atau NULL jika habis), updated_at, dan sync_status='pending' pada beans.
  Future<bool> cancelBrew({
    required String userId,
    required String brewId,
  }) async {
    final now = _utcNowWithoutMilliseconds();
    return _database.transaction((txn) async {
      final existing = await txn.query(
        'brews',
        columns: ['id', 'bean_id'],
        where: 'id = ? AND user_id = ? AND status = ?',
        whereArgs: [brewId, userId, 'aktif'],
        limit: 1,
      );
      if (existing.isEmpty) {
        return false;
      }
      final beanId = existing.single['bean_id'] as String;

      await txn.update(
        'brews',
        {
          'status': 'dibatalkan',
          'sync_status': 'pending',
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [brewId, userId],
      );

      final best = await txn.query(
        'brews',
        columns: ['id'],
        where: 'user_id = ? AND bean_id = ? AND status = ?',
        whereArgs: [userId, beanId, 'aktif'],
        orderBy: 'taste_score DESC, brewed_at_utc DESC, seq DESC',
        limit: 1,
      );

      final newBestBrewId = best.isEmpty ? null : best.single['id'] as String;

      await txn.update(
        'beans',
        {
          'best_brew_id': newBestBrewId,
          'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [beanId, userId],
      );

      return true;
    });
  }

  String _utcNowWithoutMilliseconds() {
    return DateTime.now().toUtc().toIso8601String().replaceFirst(
      RegExp(r'\.\d+Z$'),
      'Z',
    );
  }
}
