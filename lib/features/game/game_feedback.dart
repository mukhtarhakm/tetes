import 'dart:async';

import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

const gameExitVibration = Duration(milliseconds: 80);
const gameCompletionVibration = Duration(milliseconds: 250);
const gameCompletionSound = Duration(milliseconds: 500);

class GameFeedback {
  GameFeedback({
    Future<void> Function(Duration)? vibrate,
    Future<void> Function()? cancelVibration,
    Future<void> Function()? playSound,
    Future<void> Function()? stopSound,
  }) {
    final player = FlutterRingtonePlayer();
    _vibrate =
        vibrate ??
        (duration) => Vibration.vibrate(duration: duration.inMilliseconds);
    _cancelVibration = cancelVibration ?? Vibration.cancel;
    _playSound = playSound ?? () => player.playNotification(looping: false);
    _stopSound = stopSound ?? player.stop;
  }

  late final Future<void> Function(Duration) _vibrate;
  late final Future<void> Function() _cancelVibration;
  late final Future<void> Function() _playSound;
  late final Future<void> Function() _stopSound;
  int _generation = 0;
  bool _disposed = false;

  void playExit() {
    if (_disposed) return;
    unawaited(_safe(() => _vibrate(gameExitVibration)));
  }

  void playComplete() {
    if (_disposed) return;
    final generation = ++_generation;
    unawaited(_playCompletion(generation));
  }

  Future<void> _playCompletion(int generation) async {
    await Future.wait([
      _safe(() => _vibrate(gameCompletionVibration)),
      _safe(_playSound),
    ]);
    await Future<void>.delayed(gameCompletionSound);
    if (!_disposed && generation == _generation) {
      await _safe(_stopSound);
    }
  }

  void cancel() {
    ++_generation;
    unawaited(Future.wait([_safe(_cancelVibration), _safe(_stopSound)]));
  }

  void dispose() {
    _disposed = true;
    cancel();
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Umpan balik perangkat tidak boleh menghentikan game.
    }
  }
}
