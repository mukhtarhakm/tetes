import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/uuid_v4.dart';
import '../db/database_provider.dart';

final feedbackRepositoryProvider = FutureProvider<FeedbackRepository>(
  (ref) async => FeedbackRepository(await ref.watch(databaseProvider.future)),
);

class FeedbackRepository {
  const FeedbackRepository(this._database);

  static const maxLength = 500;
  final Database _database;

  Future<void> save({
    required String userId,
    required String suggestion,
    required String impression,
  }) async {
    final cleanSuggestion = suggestion.trim();
    final cleanImpression = impression.trim();
    if ((cleanSuggestion.isEmpty && cleanImpression.isEmpty) ||
        suggestion.length > maxLength ||
        impression.length > maxLength) {
      throw ArgumentError('Isi minimal satu kolom, maksimal 500 karakter.');
    }
    final now = DateTime.now().toUtc().toIso8601String().split('.').first;
    await _database.insert('feedback', {
      'id': createUuidV4(),
      'user_id': userId,
      'suggestion': cleanSuggestion.isEmpty ? null : cleanSuggestion,
      'impression': cleanImpression.isEmpty ? null : cleanImpression,
      'created_at': '${now}Z',
      'sync_status': 'pending',
    });
  }

  Future<List<Map<String, Object?>>> history(String userId) {
    return _database.query(
      'feedback',
      columns: ['id', 'suggestion', 'impression', 'created_at'],
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC, rowid DESC',
    );
  }
}
