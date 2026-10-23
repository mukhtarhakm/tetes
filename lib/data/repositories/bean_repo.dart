import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/utils/uuid_v4.dart';
import '../../features/beans/bean_model.dart';
import '../../features/beans/bean_validation.dart';
import '../../features/beans/fx_conversion.dart';
import '../../features/beans/fx_quote_service.dart';

class BeanRepository implements FxCacheStore {
  const BeanRepository(this._database);

  final Database _database;

  Future<List<Bean>> listActive(String userId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT b.*,
        b.initial_stock_g - COALESCE(
          SUM(CASE WHEN br.status = 'aktif' THEN br.dose_g ELSE 0 END),
          0
        ) AS remaining_stock_g,
        COUNT(br.id) AS brew_count,
        best_br.ratio AS best_brew_ratio,
        best_br.water_temp_c AS best_brew_water_temp_c,
        best_br.taste_score AS best_brew_taste_score,
        COALESCE(CAST(s.value AS REAL), 15.0) AS low_stock_threshold_g
      FROM beans b
      LEFT JOIN brews br ON br.bean_id = b.id
      LEFT JOIN brews best_br ON best_br.id = b.best_brew_id AND best_br.status = 'aktif'
      LEFT JOIN settings s ON s.user_id = b.user_id AND s.key = 'low_stock_threshold_g'
      WHERE b.user_id = ? AND b.archived = 0
      GROUP BY b.id
      ORDER BY b.updated_at DESC, b.name COLLATE NOCASE ASC
      ''',
      [userId],
    );
    return rows.map(Bean.fromMap).toList(growable: false);
  }

  Future<Bean?> findById({required String userId, required String id}) async {
    final rows = await _database.rawQuery(
      '''
      SELECT b.*,
        b.initial_stock_g - COALESCE(
          SUM(CASE WHEN br.status = 'aktif' THEN br.dose_g ELSE 0 END),
          0
        ) AS remaining_stock_g,
        COUNT(br.id) AS brew_count,
        best_br.ratio AS best_brew_ratio,
        best_br.water_temp_c AS best_brew_water_temp_c,
        best_br.taste_score AS best_brew_taste_score,
        COALESCE(CAST(s.value AS REAL), 15.0) AS low_stock_threshold_g
      FROM beans b
      LEFT JOIN brews br ON br.bean_id = b.id
      LEFT JOIN brews best_br ON best_br.id = b.best_brew_id AND best_br.status = 'aktif'
      LEFT JOIN settings s ON s.user_id = b.user_id AND s.key = 'low_stock_threshold_g'
      WHERE b.user_id = ? AND b.id = ?
      GROUP BY b.id
      LIMIT 1
      ''',
      [userId, id],
    );
    return rows.isEmpty ? null : Bean.fromMap(rows.single);
  }

  Future<String> create({
    required String userId,
    required BeanDraft draft,
  }) async {
    if (!draft.initialStockG.isFinite || draft.initialStockG < 0) {
      throw StateError('Stok tidak boleh negatif.');
    }
    final id = createUuidV4();
    final now = _utcNowWithoutMilliseconds();
    await _database.insert('beans', {
      'id': id,
      'user_id': userId,
      ..._draftValues(draft),
      'best_brew_id': null,
      'archived': 0,
      'created_at': now,
      'updated_at': now,
      'sync_status': 'pending',
    });
    return id;
  }

  Future<void> update({
    required String userId,
    required String id,
    required BeanDraft draft,
  }) async {
    if (!draft.initialStockG.isFinite || draft.initialStockG < 0) {
      throw StateError('Stok tidak boleh negatif.');
    }
    await _database.transaction((txn) async {
      final used = await txn.rawQuery(
        "SELECT COALESCE(SUM(dose_g), 0) AS used FROM brews WHERE user_id = ? AND bean_id = ? AND status = 'aktif'",
        [userId, id],
      );
      if (draft.initialStockG < (used.single['used'] as num).toDouble()) {
        throw StateError(
          'Stok awal tidak boleh kurang dari biji yang sudah diseduh.',
        );
      }
      final changedRows = await txn.update(
        'beans',
        {
          ..._draftValues(draft),
          'updated_at': _utcNowWithoutMilliseconds(),
          'sync_status': 'pending',
        },
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId],
      );
      if (changedRows != 1) throw StateError('Biji tidak ditemukan.');
    });
  }

  Future<void> archive({required String userId, required String id}) async {
    final changedRows = await _database.update(
      'beans',
      {
        'archived': 1,
        'updated_at': _utcNowWithoutMilliseconds(),
        'sync_status': 'pending',
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
    if (changedRows != 1) {
      throw StateError('Biji tidak ditemukan.');
    }
  }

  @override
  Future<FxQuote?> readFxCache({
    required String userId,
    required String currency,
  }) async {
    final rows = await _database.query(
      'settings',
      columns: ['value'],
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, 'fx_cache'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final cache = _decodeFxCache(rows.single['value']);
    final item = cache[currency.toUpperCase()];
    if (item is! Map) {
      return null;
    }
    final rateValue = item['rate'];
    final dateValue = item['date'];
    final rate = rateValue is num ? rateValue.toDouble() : null;
    if (rate == null ||
        !rate.isFinite ||
        rate <= 0 ||
        dateValue is! String ||
        DateTime.tryParse(dateValue) == null) {
      return null;
    }
    return FxQuote(
      currency: currency.toUpperCase(),
      rate: rate,
      date: dateValue,
      source: FxQuoteSource.cache,
    );
  }

  @override
  Future<void> writeFxCache({
    required String userId,
    required FxQuote quote,
  }) async {
    final rows = await _database.query(
      'settings',
      columns: ['value'],
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, 'fx_cache'],
      limit: 1,
    );
    final cache = rows.isEmpty
        ? <String, Object?>{}
        : _decodeFxCache(rows.single['value']);
    cache[quote.currency.toUpperCase()] = {
      'rate': quote.rate,
      'date': quote.date,
    };
    await _database.insert('settings', {
      'user_id': userId,
      'key': 'fx_cache',
      'value': jsonEncode(cache),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Map<String, Object?> _draftValues(BeanDraft draft) {
    final tagValues =
        draft.roasteryNotesTags
            .map(BeanValidation.normalizeTag)
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return {
      'name': draft.name.trim(),
      'species': draft.species.databaseValue,
      'bean_type': draft.beanType?.databaseValue,
      'arabica_percent': draft.species == BeanSpecies.campuran
          ? draft.arabicaPercent
          : null,
      'roastery': draft.isSelfRoasted
          ? BeanDefaults.selfRoasteryName
          : _nullableText(draft.roastery),
      'is_self_roasted': draft.isSelfRoasted ? 1 : 0,
      'origin': _nullableText(draft.origin),
      'process': draft.process?.databaseValue,
      'process_custom': draft.process == BeanProcess.lainnya
          ? _nullableText(draft.processCustom)
          : null,
      'roast_level': draft.roastLevel?.databaseValue,
      'roast_date': draft.roastDate,
      'pack_size_g': draft.packSizeG,
      'price_original': draft.priceOriginal,
      'currency': draft.priceOriginal == null ? null : draft.currency,
      'fx_rate': draft.priceOriginal == null ? null : draft.fxRate,
      'fx_date': draft.priceOriginal == null ? null : draft.fxDate,
      'price_idr_per_kg': draft.priceOriginal == null
          ? null
          : draft.priceIdrPerKg,
      'initial_stock_g': draft.initialStockG,
      'roastery_notes_tags': tagValues.isEmpty ? null : tagValues.join(','),
      'roastery_notes_text': _nullableText(draft.roasteryNotesText),
    };
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Map<String, Object?> _decodeFxCache(Object? value) {
    if (value is! String) {
      return <String, Object?>{};
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return <String, Object?>{};
      }
      return decoded.map((key, item) => MapEntry('$key', item));
    } on FormatException {
      return <String, Object?>{};
    }
  }

  String _utcNowWithoutMilliseconds() {
    return DateTime.now().toUtc().toIso8601String().replaceFirst(
      RegExp(r'\.\d+Z$'),
      'Z',
    );
  }
}
