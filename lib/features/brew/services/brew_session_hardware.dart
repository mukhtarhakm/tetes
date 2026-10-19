import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const shakeAccelerationThresholdMetersPerSecondSquared = 26.5;
const shakeDetectionCooldown = Duration(seconds: 2);

typedef ShakeClock = DateTime Function();

class ShakeGate {
  ShakeGate({
    ShakeClock? clock,
    this.threshold = shakeAccelerationThresholdMetersPerSecondSquared,
    this.cooldown = shakeDetectionCooldown,
  }) : _clock = clock ?? DateTime.now;

  final ShakeClock _clock;
  final double threshold;
  final Duration cooldown;
  DateTime? _lastDetection;

  bool shouldTrigger({
    required double x,
    required double y,
    required double z,
  }) {
    final magnitude = math.sqrt((x * x) + (y * y) + (z * z));
    if (magnitude < threshold) {
      return false;
    }
    final now = _clock();
    final previous = _lastDetection;
    if (previous != null && now.difference(previous) < cooldown) {
      return false;
    }
    _lastDetection = now;
    return true;
  }
}

class BrewShakeDetector {
  BrewShakeDetector({Stream<AccelerometerEvent>? events, ShakeGate? gate})
    : _events =
          events ??
          accelerometerEventStream(
            samplingPeriod: SensorInterval.normalInterval,
          ),
      _gate = gate ?? ShakeGate();

  final Stream<AccelerometerEvent> _events;
  final ShakeGate _gate;
  StreamSubscription<AccelerometerEvent>? _subscription;

  void start({
    required void Function() onShake,
    required void Function(Object error) onError,
  }) {
    _subscription ??= _events.listen((event) {
      if (_gate.shouldTrigger(x: event.x, y: event.y, z: event.z)) {
        onShake();
      }
    }, onError: onError);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

abstract interface class BrewWakeLock {
  Future<void> enable();

  Future<void> disable();
}

class SystemBrewWakeLock implements BrewWakeLock {
  const SystemBrewWakeLock();

  @override
  Future<void> disable() => WakelockPlus.disable();

  @override
  Future<void> enable() => WakelockPlus.enable();
}
