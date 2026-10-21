import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tetes/data/repositories/game_repo.dart';
import 'package:tetes/features/game/game_prototype_controller.dart';
import 'package:tetes/features/game/game_feedback.dart';
import 'package:tetes/features/game/steady_pour_control.dart';
import 'package:tetes/features/game/steady_pour_game.dart';

void main() {
  GameFeedback fakeFeedback() => GameFeedback(
    vibrate: (_) async {},
    cancelVibration: () async {},
    playSound: () async {},
    stopSound: () async {},
  );
  late Database database;
  late GameRepository repository;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE settings (
        user_id TEXT NOT NULL,
        key TEXT NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY (user_id, key)
      )
    ''');
    await database.execute('''
      CREATE TABLE game_scores (
        id TEXT PRIMARY KEY, user_id TEXT NOT NULL, level INTEGER NOT NULL,
        accuracy REAL NOT NULL, stars INTEGER NOT NULL, duration_s INTEGER NOT NULL,
        played_at TEXT NOT NULL, sync_status TEXT NOT NULL
      )
    ''');
    repository = GameRepository(database);
  });

  tearDown(() => database.close());

  test('sensitivity persists per user', () async {
    expect(await repository.get('a'), GameSensitivity.medium);
    await repository.set('a', GameSensitivity.high);
    expect(await repository.get('a'), GameSensitivity.high);
    expect(await repository.get('b'), GameSensitivity.medium);
  });

  test('only completed scores are saved, pending and scoped to user', () async {
    final failed = GameState(
      level: bloomLevel,
      elapsedSeconds: 30,
      insideSeconds: 12,
      outcome: GameOutcome.failed,
    );
    await expectLater(
      repository.saveCompletion('a', failed),
      throwsArgumentError,
    );
    expect(await database.query('game_scores'), isEmpty);

    final completed = GameState(
      level: bloomLevel,
      elapsedSeconds: 16.2,
      insideSeconds: 15,
      outcome: GameOutcome.completed,
    );
    await repository.saveCompletion('a', completed);
    final rows = await database.query('game_scores');
    expect(rows, hasLength(1));
    expect(rows.single['user_id'], 'a');
    expect(rows.single['level'], 1);
    expect(rows.single['accuracy'], closeTo(15 / 16.2, 0.00001));
    expect(rows.single['stars'], 3);
    expect(rows.single['duration_s'], 17);
    expect(rows.single['sync_status'], 'pending');
    expect(
      rows.single['id'],
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(
      rows.single['played_at'],
      matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$')),
    );
    expect(await repository.isLevelUnlocked('a', 2), isTrue);
    expect(await repository.isLevelUnlocked('b', 2), isFalse);
    expect(await repository.isLevelUnlocked('b', 1), isTrue);
    expect((await repository.bestScores('b')), isEmpty);
  });

  test('best scores use MAX for each level and active user only', () async {
    for (final row in [
      ['a', 1, 0.72, 2],
      ['a', 1, 0.91, 3],
      ['a', 2, 0.73, 2],
      ['b', 1, 0.99, 3],
    ]) {
      await database.insert('game_scores', {
        'id': '${row[0]}-${row[1]}-${row[2]}',
        'user_id': row[0],
        'level': row[1],
        'accuracy': row[2],
        'stars': row[3],
        'duration_s': 20,
        'played_at': '2026-10-21T00:00:00Z',
        'sync_status': 'pending',
      });
    }
    final best = await repository.bestScores('a');
    expect(best[1]!.accuracy, 0.91);
    expect(best[1]!.stars, 3);
    expect(best[2]!.accuracy, 0.73);
    expect(await repository.isLevelUnlocked('a', 3), isTrue);
    expect(await repository.isLevelUnlocked('b', 3), isFalse);
  });

  test(
    'controller saves a win once and unlocks next level, not a failure',
    () async {
      final events = StreamController<GyroscopeEvent>.broadcast();
      final controller = GamePrototypeController(
        userId: 'a',
        repository: repository,
        events: events.stream,
        feedback: fakeFeedback(),
      );
      await controller.initialize();
      expect(controller.isUnlocked(1), isTrue);
      expect(controller.isUnlocked(2), isFalse);
      controller.selectLevel(pouringLevel);
      expect(controller.phase, GamePrototypePhase.selection);
      controller.selectLevel(bloomLevel);
      controller.calibrateAndStart();
      final start = DateTime.utc(2026);
      for (var i = 0; i <= 31; i++) {
        events.add(
          GyroscopeEvent(0, 0, 0, start.add(Duration(milliseconds: i * 100))),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(controller.phase, GamePrototypePhase.playing);
      controller.game = const GameState(
        level: bloomLevel,
        elapsedSeconds: 20,
        insideSeconds: 14.95,
      );
      events.add(
        GyroscopeEvent(0, 0, 0, start.add(const Duration(milliseconds: 3200))),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.phase, GamePrototypePhase.result);
      expect(controller.isUnlocked(2), isTrue);
      expect(await database.query('game_scores'), hasLength(1));

      controller.returnToSelection();
      controller.selectLevel(pouringLevel);
      controller.calibrateAndStart();
      final nextStart = start.add(const Duration(seconds: 10));
      for (var i = 0; i <= 31; i++) {
        events.add(
          GyroscopeEvent(
            0,
            0,
            0,
            nextStart.add(Duration(milliseconds: i * 100)),
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);
      controller.game = const GameState(
        level: pouringLevel,
        elapsedSeconds: 39.95,
        insideSeconds: 1,
      );
      events.add(
        GyroscopeEvent(
          0,
          0,
          0,
          nextStart.add(const Duration(milliseconds: 3200)),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.game!.outcome, GameOutcome.failed);
      expect(await database.query('game_scores'), hasLength(1));
      controller.dispose();
      await events.close();
    },
  );

  test('vibrates once per exit from zone', () async {
    var vibrations = 0;
    final events = StreamController<GyroscopeEvent>.broadcast();
    final controller = GamePrototypeController(
      userId: 'a',
      repository: repository,
      events: events.stream,
      feedback: GameFeedback(
        vibrate: (_) async {
          vibrations++;
        },
        cancelVibration: () async {},
        playSound: () async {},
        stopSound: () async {},
      ),
    );
    await controller.initialize();
    controller.selectLevel(bloomLevel);
    controller.calibrateAndStart();
    final start = DateTime.utc(2026);
    for (var i = 0; i <= 31; i++) {
      events.add(
        GyroscopeEvent(0, 0, 0, start.add(Duration(milliseconds: i * 100))),
      );
    }
    events.add(
      GyroscopeEvent(0, 10, 0, start.add(const Duration(milliseconds: 3200))),
    );
    events.add(
      GyroscopeEvent(0, 10, 0, start.add(const Duration(milliseconds: 3300))),
    );
    await Future<void>.delayed(Duration.zero);
    expect(vibrations, 1);
    controller.dispose();
    await events.close();
  });

  test('calibration sets zero and pause cancels sensor', () async {
    var cancellations = 0;
    var vibrations = 0;
    var sounds = 0;
    final events = StreamController<GyroscopeEvent>.broadcast(
      onCancel: () => cancellations++,
    );
    final controller = GamePrototypeController(
      userId: 'a',
      repository: repository,
      events: events.stream,
      feedback: GameFeedback(
        vibrate: (_) async {
          vibrations++;
        },
        cancelVibration: () async {},
        playSound: () async {
          sounds++;
        },
        stopSound: () async {},
      ),
    );
    await controller.initialize();
    controller.selectLevel(bloomLevel);
    controller.calibrateAndStart();
    expect(controller.position.x, 0);
    expect(controller.position.y, 0);
    final start = DateTime.utc(2026);
    for (var i = 0; i <= 31; i++) {
      events.add(
        GyroscopeEvent(0, 0, 0, start.add(Duration(milliseconds: i * 100))),
      );
    }
    events.add(
      GyroscopeEvent(0, 1, 0, start.add(const Duration(milliseconds: 3200))),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.phase, GamePrototypePhase.playing);
    expect(controller.position.x, greaterThan(0));
    controller.pause();
    expect(controller.phase, GamePrototypePhase.paused);
    expect(cancellations, 1);
    final pausedX = controller.position.x;
    events.add(
      GyroscopeEvent(0, 10, 0, start.add(const Duration(milliseconds: 100))),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.position.x, pausedX);
    expect(vibrations, 0);
    expect(sounds, 0);
    controller.resume();
    expect(controller.phase, GamePrototypePhase.calibration);
    controller.calibrateAndStart();
    expect(controller.position.x, 0);
    controller.dispose();
    await events.close();
  });

  test('gyroscope error disables game without throwing', () async {
    final events = StreamController<GyroscopeEvent>.broadcast();
    final controller = GamePrototypeController(
      userId: 'a',
      repository: repository,
      events: events.stream,
      feedback: fakeFeedback(),
    );
    await controller.initialize();
    events.addError(StateError('sensor missing'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.phase, GamePrototypePhase.unavailable);
    expect(controller.unavailableMessage, contains('Gyroscope'));
    controller.dispose();
    await events.close();
  });

  test('silent gyroscope disables game after two seconds', () async {
    final events = StreamController<GyroscopeEvent>.broadcast();
    final controller = GamePrototypeController(
      userId: 'a',
      repository: repository,
      events: events.stream,
      feedback: fakeFeedback(),
    );
    await controller.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    expect(controller.phase, GamePrototypePhase.unavailable);
    expect(controller.unavailableMessage, contains('Gyroscope'));
    controller.dispose();
    await events.close();
  });
}
