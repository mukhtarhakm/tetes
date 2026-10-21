import 'dart:math' as math;

import 'steady_pour_control.dart';

class GameLevel {
  const GameLevel({
    required this.number,
    required this.name,
    required this.zoneRadius,
    required this.orbitRadius,
    required this.orbitRadiansPerSecond,
    required this.requiredInsideSeconds,
    required this.timeLimitSeconds,
  });

  final int number;
  final String name;
  final double zoneRadius;
  final double orbitRadius;
  final double orbitRadiansPerSecond;
  final double requiredInsideSeconds;
  final double timeLimitSeconds;
}

const bloomLevel = GameLevel(
  number: 1,
  name: 'Bloom',
  zoneRadius: 0.45,
  orbitRadius: 0,
  orbitRadiansPerSecond: 0,
  requiredInsideSeconds: 15,
  timeLimitSeconds: 30,
);

const pouringLevel = GameLevel(
  number: 2,
  name: 'Pouring',
  zoneRadius: 0.32,
  orbitRadius: 0.38,
  orbitRadiansPerSecond: 0.35,
  requiredInsideSeconds: 20,
  timeLimitSeconds: 40,
);

const finishLevel = GameLevel(
  number: 3,
  name: 'Finish',
  zoneRadius: 0.24,
  orbitRadius: 0.46,
  orbitRadiansPerSecond: 0.7,
  requiredInsideSeconds: 25,
  timeLimitSeconds: 45,
);

const gameLevels = [bloomLevel, pouringLevel, finishLevel];
const threeStarAccuracy = 0.90;
const twoStarAccuracy = 0.70;
const levelOneHintDuration = Duration(seconds: 5);

enum GameOutcome { playing, completed, failed }

class GameState {
  const GameState({
    required this.level,
    this.position = const PourPosition.center(),
    this.elapsedSeconds = 0,
    this.insideSeconds = 0,
    this.outcome = GameOutcome.playing,
  });

  final GameLevel level;
  final PourPosition position;
  final double elapsedSeconds;
  final double insideSeconds;
  final GameOutcome outcome;

  double get zoneX =>
      level.orbitRadius *
      math.cos(elapsedSeconds * level.orbitRadiansPerSecond);
  double get zoneY =>
      level.orbitRadius *
      math.sin(elapsedSeconds * level.orbitRadiansPerSecond);
  bool get isInsideZone =>
      math.pow(position.x - zoneX, 2) + math.pow(position.y - zoneY, 2) <=
      math.pow(level.zoneRadius, 2);
  double get waterProgress =>
      (insideSeconds / level.requiredInsideSeconds).clamp(0, 1).toDouble();
  double get remainingSeconds =>
      math.max(0, level.timeLimitSeconds - elapsedSeconds);
  double get accuracy => elapsedSeconds <= 0
      ? 0
      : (insideSeconds / elapsedSeconds).clamp(0, 1).toDouble();
  int get stars =>
      outcome == GameOutcome.completed ? starsForAccuracy(accuracy) : 0;

  GameState withPosition(PourPosition value) => GameState(
    level: level,
    position: value,
    elapsedSeconds: elapsedSeconds,
    insideSeconds: insideSeconds,
    outcome: outcome,
  );
}

int starsForAccuracy(double accuracy) {
  if (accuracy >= threeStarAccuracy) return 3;
  if (accuracy >= twoStarAccuracy) return 2;
  return 1;
}

GameState advanceGame(
  GameState current, {
  required double xRadiansPerSecond,
  required double yRadiansPerSecond,
  required double dtSeconds,
  required GameSensitivity sensitivity,
}) {
  if (current.outcome != GameOutcome.playing ||
      !dtSeconds.isFinite ||
      dtSeconds <= 0) {
    return current;
  }
  final dt = math.min(
    math.min(dtSeconds, maxSensorDeltaSeconds),
    current.remainingSeconds,
  );
  if (dt <= 0) return current;
  final position = advancePourPosition(
    current.position,
    xRadiansPerSecond: xRadiansPerSecond,
    yRadiansPerSecond: yRadiansPerSecond,
    dtSeconds: dt,
    sensitivity: sensitivity,
  );
  final elapsed = current.elapsedSeconds + dt;
  final zoneX =
      current.level.orbitRadius *
      math.cos(elapsed * current.level.orbitRadiansPerSecond);
  final zoneY =
      current.level.orbitRadius *
      math.sin(elapsed * current.level.orbitRadiansPerSecond);
  final inside =
      math.pow(position.x - zoneX, 2) + math.pow(position.y - zoneY, 2) <=
      math.pow(current.level.zoneRadius, 2);
  final insideSeconds = current.insideSeconds + (inside ? dt : 0);
  final outcome = elapsed >= current.level.timeLimitSeconds
      ? GameOutcome.failed
      : insideSeconds >= current.level.requiredInsideSeconds
      ? GameOutcome.completed
      : GameOutcome.playing;
  return GameState(
    level: current.level,
    position: position,
    elapsedSeconds: elapsed,
    insideSeconds: insideSeconds,
    outcome: outcome,
  );
}
