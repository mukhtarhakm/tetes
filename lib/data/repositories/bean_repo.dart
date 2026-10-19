import 'package:sqflite/sqflite.dart';

import '../../core/utils/uuid_v4.dart';
import '../../features/beans/bean_model.dart';

class BeanRepository {
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
        COUNT(br.id) AS brew_count
      FROM beans b
      LEFT JOIN brews br ON br.bean_id = b.id
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
        COUNT(br.id) AS brew_count
      FROM beans b
      LEFT JOIN brews br ON br.bean_id = b.id
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
    final id = createUuidV4();
    final now = _utcNowWithoutMilliseconds();
    await _database.insert('beans', {
      'id': id,
      'user_id': userId,
      ..._draftValues(draft),
      'fx_rate': null,
      'fx_date': null,
      'price_idr_per_kg': null,
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
    final changedRows = await _database.update(
      'beans',
      {
        ..._draftValues(draft),
        'fx_rate': null,
        'fx_date': null,
        'price_idr_per_kg': null,
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

  Map<String, Object?> _draftValues(BeanDraft draft) {
    final tagValues =
        draft.roasteryNotesTags.map((tag) => tag.databaseValue).toList()
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
      'roast_level': draft.roastLevel?.databaseValue,
      'roast_date': draft.roastDate,
      'price_original': draft.priceOriginal,
      'currency': draft.priceOriginal == null ? null : draft.currency,
      'initial_stock_g': draft.initialStockG,
      'roastery_notes_tags': tagValues.isEmpty ? null : tagValues.join(','),
      'roastery_notes_text': _nullableText(draft.roasteryNotesText),
    };
  }

  String? _nullableText(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  String _utcNowWithoutMilliseconds() {
    return DateTime.now().toUtc().toIso8601String().replaceFirst(
      RegExp(r'\.\d+Z$'),
      'Z',
    );
  }
}
