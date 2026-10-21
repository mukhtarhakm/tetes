import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/uuid_v4.dart';
import '../../features/game/steady_pour_control.dart';
import '../../features/game/steady_pour_game.dart';
import '../db/database_provider.dart';

final gameRepositoryProvider = FutureProvider<GameRepository>(
  (ref) async => GameRepository(await ref.watch(databaseProvider.future)),
);

class GameRepository {
  const GameRepository(this._database);

  final Database _database;

  Future<Map<int, BestGameScore>> bestScores(String userId) async {
    final rows = await _database.rawQuery(
      '''
      SELECT level, MAX(accuracy) AS best_accuracy, MAX(stars) AS best_stars
      FROM game_scores
      WHERE user_id = ?
      GROUP BY level
    ''',
      [userId],
    );
    return {
      for (final row in rows)
        row['level'] as int: BestGameScore(
          accuracy: (row['best_accuracy'] as num).toDouble(),
          stars: row['best_stars'] as int,
        ),
    };
  }

  Future<bool> isLevelUnlocked(String userId, int level) async {
    if (level == 1) return true;
    if (level < 1 || level > gameLevels.length) return false;
    final rows = await _database.rawQuery(
      '''
      SELECT 1 FROM game_scores
      WHERE user_id = ? AND level = ?
      LIMIT 1
    ''',
      [userId, level - 1],
    );
    return rows.isNotEmpty;
  }

  Future<void> saveCompletion(String userId, GameState state) async {
    if (state.outcome != GameOutcome.completed ||
        state.elapsedSeconds <= 0 ||
        state.elapsedSeconds >= state.level.timeLimitSeconds ||
        state.insideSeconds < state.level.requiredInsideSeconds ||
        state.insideSeconds > state.elapsedSeconds ||
        !gameLevels.contains(state.level)) {
      throw ArgumentError('Only completed levels can be saved.');
    }
    final now = DateTime.now().toUtc();
    final playedAt = '${now.toIso8601String().split('.').first}Z';
    await _database.insert('game_scores', {
      'id': createUuidV4(),
      'user_id': userId,
      'level': state.level.number,
      'accuracy': state.accuracy,
      'stars': state.stars,
      'duration_s': state.elapsedSeconds.ceil(),
      'played_at': playedAt,
      'sync_status': 'pending',
    });
  }

  Future<GameSensitivity> get(String userId) async {
    final rows = await _database.query(
      'settings',
      columns: ['value'],
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, 'game_sensitivity'],
      limit: 1,
    );
    final value = rows.isEmpty ? null : rows.single['value'];
    return GameSensitivity.values.firstWhere(
      (item) => item.name == value,
      orElse: () => GameSensitivity.medium,
    );
  }

  Future<void> set(String userId, GameSensitivity sensitivity) async {
    await _database.rawInsert(
      '''
      INSERT INTO settings (user_id, key, value) VALUES (?, ?, ?)
      ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value
    ''',
      [userId, 'game_sensitivity', sensitivity.name],
    );
  }

  Future<bool> hasSeenTutorial(String userId) async {
    final rows = await _database.query(
      'settings',
      columns: ['value'],
      where: 'user_id = ? AND key = ?',
      whereArgs: [userId, 'game_tutorial_seen'],
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['value'] == '1';
  }

  Future<void> markTutorialSeen(String userId) async {
    await _database.rawInsert(
      '''
      INSERT INTO settings (user_id, key, value) VALUES (?, ?, '1')
      ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value
    ''',
      [userId, 'game_tutorial_seen'],
    );
  }
}

class BestGameScore {
  const BestGameScore({required this.accuracy, required this.stars});

  final double accuracy;
  final int stars;
}
