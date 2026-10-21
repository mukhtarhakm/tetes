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
    await _database.insert('events', {
      'id': id,
      'user_id': userId,
      ..._values(draft),
      'deleted': 0,
      'created_at': now,
      'updated_at': now,
      'sync_status': 'pending',
    });
    return id;
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
