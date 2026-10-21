import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/game/steady_pour_control.dart';

void main() {
  test('tested axes keep horizontal and invert vertical movement', () {
    expect(invertX, isFalse);
    expect(invertY, isTrue);
    expect(mapGyroscopeToPour(0, 1).x, greaterThan(0));
    expect(mapGyroscopeToPour(0, -1).x, lessThan(0));
    expect(mapGyroscopeToPour(1, 0).y, greaterThan(0));
    expect(mapGyroscopeToPour(-1, 0).y, lessThan(0));
    for (final (gyroX, gyroY, expectedX, expectedY) in [
      (0.0, 1.0, 1, 0),
      (0.0, -1.0, -1, 0),
      (1.0, 0.0, 0, 1),
      (-1.0, 0.0, 0, -1),
    ]) {
      final speed = mapGyroscopeToPour(gyroX, gyroY);
      final position = advancePourPosition(
        const PourPosition.center(),
        xRadiansPerSecond: speed.x,
        yRadiansPerSecond: speed.y,
        dtSeconds: 0.05,
        sensitivity: GameSensitivity.medium,
      );
      expect(position.x.sign, expectedX);
      expect(position.y.sign, expectedY);
    }
  });

  test('each invert switch reverses both signs on its own axis', () {
    for (final speed in [-1.0, 1.0]) {
      final horizontal = mapGyroscopeToPour(0, speed, invertHorizontal: false);
      final reversedHorizontal = mapGyroscopeToPour(
        0,
        speed,
        invertHorizontal: true,
      );
      expect(reversedHorizontal.x, -horizontal.x);

      final vertical = mapGyroscopeToPour(speed, 0, invertVertical: false);
      final reversedVertical = mapGyroscopeToPour(
        speed,
        0,
        invertVertical: true,
      );
      expect(reversedVertical.y, -vertical.y);
    }
  });
}
