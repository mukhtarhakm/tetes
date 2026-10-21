import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/game/steady_pour_control.dart';
import 'package:tetes/features/game/steady_pour_game.dart';

void main() {
  test('level constants have intended order and time targets', () {
    expect(gameLevels.map((e) => e.name), ['Bloom', 'Pouring', 'Finish']);
    expect(gameLevels.map((e) => e.requiredInsideSeconds), [15, 20, 25]);
    expect(gameLevels.map((e) => e.timeLimitSeconds), [30, 40, 45]);
    expect(bloomLevel.zoneRadius, greaterThan(pouringLevel.zoneRadius));
    expect(pouringLevel.zoneRadius, greaterThan(finishLevel.zoneRadius));
    expect(
      pouringLevel.orbitRadiansPerSecond,
      lessThan(finishLevel.orbitRadiansPerSecond),
    );
  });

  test('bar only grows while point is inside the zone', () {
    final inside = advanceGame(
      const GameState(level: bloomLevel),
      xRadiansPerSecond: 0,
      yRadiansPerSecond: 0,
      dtSeconds: 0.1,
      sensitivity: GameSensitivity.medium,
    );
    expect(inside.insideSeconds, closeTo(0.1, 0.00001));
    expect(inside.waterProgress, greaterThan(0));
    final outside = advanceGame(
      GameState(
        level: bloomLevel,
        position: const PourPosition(maxPourAngleRadians, 0),
        elapsedSeconds: inside.elapsedSeconds,
        insideSeconds: inside.insideSeconds,
      ),
      xRadiansPerSecond: 0,
      yRadiansPerSecond: 0,
      dtSeconds: 0.1,
      sensitivity: GameSensitivity.medium,
    );
    expect(outside.isInsideZone, isFalse);
    expect(outside.waterProgress, inside.waterProgress);
  });

  test('large dt cannot jump across zone or fill the bar', () {
    final next = advanceGame(
      const GameState(level: pouringLevel),
      xRadiansPerSecond: 10,
      yRadiansPerSecond: 0,
      dtSeconds: 10,
      sensitivity: GameSensitivity.high,
    );
    expect(next.elapsedSeconds, maxSensorDeltaSeconds);
    expect(next.insideSeconds, lessThanOrEqualTo(maxSensorDeltaSeconds));
    expect(next.waterProgress, lessThan(0.01));
    expect(next.position.x, lessThanOrEqualTo(1));
  });

  test('completion needs full bar before time limit', () {
    final success = advanceGame(
      const GameState(
        level: bloomLevel,
        elapsedSeconds: 20,
        insideSeconds: 14.95,
      ),
      xRadiansPerSecond: 0,
      yRadiansPerSecond: 0,
      dtSeconds: 0.1,
      sensitivity: GameSensitivity.medium,
    );
    expect(success.outcome, GameOutcome.completed);
    expect(success.waterProgress, 1);
    final timeout = advanceGame(
      const GameState(
        level: bloomLevel,
        elapsedSeconds: 29.95,
        insideSeconds: 14.95,
      ),
      xRadiansPerSecond: 0,
      yRadiansPerSecond: 0,
      dtSeconds: 10,
      sensitivity: GameSensitivity.medium,
    );
    expect(timeout.outcome, GameOutcome.failed);
    expect(timeout.remainingSeconds, 0);
    expect(timeout.stars, 0);
  });

  test('accuracy and star boundaries are exact', () {
    expect(starsForAccuracy(0.90), 3);
    expect(starsForAccuracy(0.8999), 2);
    expect(starsForAccuracy(0.70), 2);
    expect(starsForAccuracy(0.6999), 1);
    const state = GameState(
      level: bloomLevel,
      elapsedSeconds: 20,
      insideSeconds: 15,
      outcome: GameOutcome.completed,
    );
    expect(state.accuracy, 0.75);
    expect(state.stars, 2);
  });
}
