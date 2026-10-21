import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/game/game_orientation_lock.dart';

void main() {
  test(
    'portrait lock restores app orientations after background and Back',
    () async {
      final calls = <List<DeviceOrientation>>[];
      final lock = GameOrientationLock(
        setOrientations: (orientations) async {
          calls.add(List.of(orientations));
        },
      );
      lock.lockPortrait();
      lock.restoreAppOrientation();
      lock.lockPortrait();
      lock.dispose();
      await lock.settled;
      expect(calls, [
        [DeviceOrientation.portraitUp],
        <DeviceOrientation>[],
        [DeviceOrientation.portraitUp],
        <DeviceOrientation>[],
      ]);
      lock.lockPortrait();
      await lock.settled;
      expect(calls, hasLength(4));
    },
  );
}
