import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/uuid_v4.dart';
import '../../features/chat/chat_message.dart';
import '../db/database_provider.dart';

final chatRepositoryProvider = FutureProvider<ChatRepository>(
  (ref) async => ChatRepository(await ref.watch(databaseProvider.future)),
);

class ChatRepository {
  const ChatRepository(this._database);

  final Database _database;

  Future<List<ChatMessage>> list(String userId) async {
    final rows = await _database.query(
      'chat_messages',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at ASC, rowid ASC',
    );
    return rows
        .map(
          (row) => ChatMessage(
            id: row['id'] as String,
            role: row['role'] as String,
            content: row['content'] as String,
            createdAt: DateTime.parse(row['created_at'] as String),
            failed: row['status'] == 'failed',
          ),
        )
        .toList(growable: false);
  }

  Future<ChatMessage> add({
    required String userId,
    String? beanId,
    required String role,
    required String content,
  }) async {
    if (role != 'user' && role != 'assistant') {
      throw ArgumentError.value(role, 'role');
    }
    final message = ChatMessage(
      id: createUuidV4(),
      role: role,
      content: content,
      createdAt: DateTime.now().toUtc(),
      failed: false,
    );
    await _database.insert('chat_messages', {
      'id': message.id,
      'user_id': userId,
      'bean_id': beanId,
      'role': role,
      'content': content,
      'created_at': message.createdAt.toIso8601String().replaceFirst(
        RegExp(r'\.\d+Z$'),
        'Z',
      ),
      'status': 'sent',
    });
    return message;
  }

  Future<void> markFailed({required String userId, required String id}) async {
    await _database.update(
      'chat_messages',
      {'status': 'failed'},
      where: 'id = ? AND user_id = ? AND role = ?',
      whereArgs: [id, userId, 'user'],
    );
  }

  Future<void> deleteAll(String userId) => _database
      .delete('chat_messages', where: 'user_id = ?', whereArgs: [userId])
      .then((_) {});

  Future<int> countUserToday(String userId, DateTime nowUtc) async {
    final jakarta = nowUtc.toUtc().add(const Duration(hours: 7));
    final start = DateTime.utc(
      jakarta.year,
      jakarta.month,
      jakarta.day,
    ).subtract(const Duration(hours: 7));
    final end = start.add(const Duration(days: 1));
    String stamp(DateTime value) =>
        value.toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');
    final rows = await _database.rawQuery(
      '''
      SELECT COUNT(*) AS count FROM chat_messages
      WHERE user_id = ? AND role = 'user' AND created_at >= ? AND created_at < ?
    ''',
      [userId, stamp(start), stamp(end)],
    );
    return (rows.single['count'] as num).toInt();
  }

  Future<List<Map<String, Object?>>> recentBrews(
    String userId,
    String beanId,
  ) async {
    return _database.query(
      'brews',
      columns: [
        'brewed_at_utc',
        'dose_g',
        'ratio',
        'water_temp_c',
        'grind',
        'taste_score',
        'taste_tags',
      ],
      where: 'user_id = ? AND bean_id = ? AND status = ?',
      whereArgs: [userId, beanId, 'aktif'],
      orderBy: 'brewed_at_utc DESC, seq DESC',
      limit: 5,
    );
  }
}
