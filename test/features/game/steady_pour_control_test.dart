import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/game/steady_pour_control.dart';

void main() {
  test('integrates angular velocity with dt and sensitivity', () {
    final slow = advancePourPosition(
      const PourPosition.center(),
      xRadiansPerSecond: 1,
      yRadiansPerSecond: 0,
      dtSeconds: 0.05,
      sensitivity: GameSensitivity.low,
    );
    final fast = advancePourPosition(
      const PourPosition.center(),
      xRadiansPerSecond: 1,
      yRadiansPerSecond: 0,
      dtSeconds: 0.05,
      sensitivity: GameSensitivity.high,
    );
    expect(fast.x, greaterThan(slow.x));
    expect(slow.y, 0);
  });

  test('damping returns dot toward center', () {
    final next = advancePourPosition(
      const PourPosition(0.5, -0.5),
      xRadiansPerSecond: 0,
      yRadiansPerSecond: 0,
      dtSeconds: 0.1,
      sensitivity: GameSensitivity.medium,
    );
    expect(next.xRadians, lessThan(0.5));
    expect(next.yRadians, greaterThan(-0.5));
  });

  test('large dt is capped and position stays within bounds', () {
    final next = advancePourPosition(
      const PourPosition.center(),
      xRadiansPerSecond: 10,
      yRadiansPerSecond: -10,
      dtSeconds: 10,
      sensitivity: GameSensitivity.high,
    );
    expect(next.x, 1);
    expect(next.y, -1);
    expect(
      advancePourPosition(
        const PourPosition.center(),
        xRadiansPerSecond: 1,
        yRadiansPerSecond: 0,
        dtSeconds: double.nan,
        sensitivity: GameSensitivity.medium,
      ).x,
      0,
    );
  });
}
