import 'package:sqflite/sqflite.dart';

import '../../core/utils/event_time.dart';
import '../../core/utils/uuid_v4.dart';
import '../../features/explore/event_model.dart';

class EventRepository {
  const EventRepository(this._database);

  final Database _database;

  Future<List<EventItem>> listActive(String userId) async {
    final rows = await _database.query(
      'events',
      where: 'user_id = ? AND deleted = 0',
      whereArgs: [userId],
      orderBy: 'start_utc ASC',
    );
    return rows.map(EventItem.fromMap).toList(growable: false);
  }

  Future<EventItem?> findById(String userId, String id) async {
    final rows = await _database.query(
      'events',
      where: 'user_id = ? AND id = ? AND deleted = 0',
      whereArgs: [userId, id],
      limit: 1,
    );
    return rows.isEmpty ? null : EventItem.fromMap(rows.single);
  }

  Future<String> create(String userId, EventDraft draft) async {
    draft.validate();
    final id = createUuidV4();
    final now = EventTime.utcText(DateTime.now());
    await _database.transaction((txn) async {
      final baseId = await _nextNotificationBaseId(txn, userId);
      await txn.insert('events', {
        'id': id,
        'user_id': userId,
        ..._values(draft),
        'notif_base_id': baseId,
        'deleted': 0,
        'created_at': now,
        'updated_at': now,
        'sync_status': 'pending',
      });
    });
    return id;
  }

  Future<void> ensureNotificationBaseIds(String userId) async {
    await _database.transaction((txn) async {
      final rows = await txn.query(
        'events',
        columns: ['id'],
        where: 'user_id = ? AND deleted = 0 AND notif_base_id IS NULL',
        whereArgs: [userId],
        orderBy: 'created_at ASC',
      );
      for (final row in rows) {
        final baseId = await _nextNotificationBaseId(txn, userId);
        await txn.update(
          'events',
          {
            'notif_base_id': baseId,
            'updated_at': EventTime.utcText(DateTime.now()),
            'sync_status': 'pending',
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [row['id'], userId],
        );
      }
    });
  }

  Future<void> assignPulledNotificationBaseIds(String userId) async {
    await _database.transaction((txn) async {
      final rows = await txn.query(
        'events',
        columns: ['id'],
        where: 'user_id = ? AND deleted = 0 AND notif_base_id IS NULL',
        whereArgs: [userId],
        orderBy: 'created_at ASC, id ASC',
      );
      for (final row in rows) {
        await txn.update(
          'events',
          {'notif_base_id': await _nextNotificationBaseId(txn, userId)},
          where: 'id = ? AND user_id = ?',
          whereArgs: [row['id'], userId],
        );
      }
    });
  }

  Future<int> _nextNotificationBaseId(Transaction txn, String userId) async {
    final rows = await txn.query(
      'settings',
      columns: ['value'],
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, 'next_event_notif_base_id'],
      limit: 1,
    );
    final maxRows = await txn.rawQuery(
      'SELECT MAX(notif_base_id) AS max_id FROM events WHERE user_id = ?',
      [userId],
    );
    final stored = rows.isEmpty
        ? 1
        : int.tryParse(rows.single['value'] as String) ?? 1;
    final existing = ((maxRows.single['max_id'] as num?)?.toInt() ?? 0) + 1;
    final next = stored > existing ? stored : existing;
    if (next > 99999999) {
      throw StateError('Batas ID notifikasi event tercapai.');
    }
    await txn.insert('settings', {
      'user_id': userId,
      'key': 'next_event_notif_base_id',
      'value': '${next + 1}',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return next;
  }

  Future<void> update(String userId, String id, EventDraft draft) async {
    draft.validate();
    final count = await _database.update(
      'events',
      {
        ..._values(draft),
        'updated_at': EventTime.utcText(DateTime.now()),
        'sync_status': 'pending',
      },
      where: 'id = ? AND user_id = ? AND deleted = 0',
      whereArgs: [id, userId],
    );
    if (count != 1) throw StateError('Event tidak ditemukan.');
  }

  Future<void> softDelete(String userId, String id) async {
    final count = await _database.update(
      'events',
      {
        'deleted': 1,
        'updated_at': EventTime.utcText(DateTime.now()),
        'sync_status': 'pending',
      },
      where: 'id = ? AND user_id = ? AND deleted = 0',
      whereArgs: [id, userId],
    );
    if (count != 1) throw StateError('Event tidak ditemukan.');
  }

  Map<String, Object?> _values(EventDraft draft) => {
    'name': draft.name.trim(),
    'event_type': draft.eventType,
    'location': _optional(draft.location),
    'notes': _optional(draft.notes),
    'start_utc': EventTime.utcText(draft.startUtc),
    'source_zone': draft.sourceZone,
    'reminder_minutes': draft.reminderText,
  };

  String? _optional(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
