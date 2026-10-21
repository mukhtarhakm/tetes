import 'dart:math' as math;

enum GameSensitivity { low, medium, high }

extension GameSensitivityLabel on GameSensitivity {
  String get label => switch (this) {
    GameSensitivity.low => 'Rendah',
    GameSensitivity.medium => 'Sedang',
    GameSensitivity.high => 'Tinggi',
  };

  double get multiplier => switch (this) {
    GameSensitivity.low => 0.6,
    GameSensitivity.medium => 1.0,
    GameSensitivity.high => 1.5,
  };
}

const maxPourAngleRadians = 0.7;
const pourDampingPerSecond = 0.8;
const maxSensorDeltaSeconds = 0.1;
const invertX = false;
const invertY = true;

({double x, double y}) mapGyroscopeToPour(
  double gyroscopeX,
  double gyroscopeY, {
  bool invertHorizontal = invertX,
  bool invertVertical = invertY,
}) => (
  x: invertHorizontal ? -gyroscopeY : gyroscopeY,
  y: invertVertical ? gyroscopeX : -gyroscopeX,
);

class PourPosition {
  const PourPosition(this.xRadians, this.yRadians);

  const PourPosition.center() : this(0, 0);

  final double xRadians;
  final double yRadians;

  double get x => xRadians / maxPourAngleRadians;
  double get y => yRadians / maxPourAngleRadians;
}

PourPosition advancePourPosition(
  PourPosition current, {
  required double xRadiansPerSecond,
  required double yRadiansPerSecond,
  required double dtSeconds,
  required GameSensitivity sensitivity,
}) {
  if (!dtSeconds.isFinite || dtSeconds <= 0) return current;
  final dt = math.min(dtSeconds, maxSensorDeltaSeconds);
  final damping = math.exp(-pourDampingPerSecond * dt);
  double next(double angle, double speed) =>
      ((angle + speed * sensitivity.multiplier * dt) * damping)
          .clamp(-maxPourAngleRadians, maxPourAngleRadians)
          .toDouble();
  return PourPosition(
    next(current.xRadians, xRadiansPerSecond),
    next(current.yRadians, yRadiansPerSecond),
  );
}
