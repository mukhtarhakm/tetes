import 'dart:async';

import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

const stageTransitionVibrationDuration = Duration(milliseconds: 700);
const sessionCompletionVibrationDuration = Duration(milliseconds: 1400);
const sessionCompletionSoundDuration = Duration(milliseconds: 1400);

typedef BrewFeedbackAction = Future<void> Function();
typedef BrewFeedbackVibrate = Future<void> Function(Duration duration);
typedef BrewFeedbackDelay = Future<void> Function(Duration duration);

class BrewStageFeedback {
  BrewStageFeedback({
    BrewFeedbackVibrate? vibrate,
    BrewFeedbackAction? cancelVibration,
    BrewFeedbackAction? playTransitionSound,
    BrewFeedbackAction? playCompletionSound,
    BrewFeedbackAction? stopSound,
    BrewFeedbackDelay? delay,
  }) {
    final player = FlutterRingtonePlayer();
    _vibrate =
        vibrate ??
        (duration) => Vibration.vibrate(duration: duration.inMilliseconds);
    _cancelVibration = cancelVibration ?? Vibration.cancel;
    _playTransitionSound =
        playTransitionSound ?? (() => player.playNotification(looping: false));
    _playCompletionSound =
        playCompletionSound ?? (() => player.playAlarm(looping: true));
    _stopSound = stopSound ?? player.stop;
    _delay = delay ?? ((duration) => Future<void>.delayed(duration));
  }

  late final BrewFeedbackVibrate _vibrate;
  late final BrewFeedbackAction _cancelVibration;
  late final BrewFeedbackAction _playTransitionSound;
  late final BrewFeedbackAction _playCompletionSound;
  late final BrewFeedbackAction _stopSound;
  late final BrewFeedbackDelay _delay;

  int _generation = 0;
  bool _disposed = false;

  Future<void> playTransition() async {
    if (_disposed) {
      return;
    }
    final generation = ++_generation;
    await _stopOutputs();
    if (!_isCurrent(generation)) {
      return;
    }
    await Future.wait([
      _safeVibrate(stageTransitionVibrationDuration),
      _safeRun(_playTransitionSound),
    ]);
  }

  Future<void> playCompleted() async {
    if (_disposed) {
      return;
    }
    final generation = ++_generation;
    await _stopOutputs();
    if (!_isCurrent(generation)) {
      return;
    }
    await Future.wait([
      _safeVibrate(sessionCompletionVibrationDuration),
      _safeRun(_playCompletionSound),
    ]);
    await _delay(sessionCompletionSoundDuration);
    if (_isCurrent(generation)) {
      await _safeRun(_stopSound);
    }
  }

  void cancel() {
    ++_generation;
    unawaited(_stopOutputs());
  }

  void dispose() {
    _disposed = true;
    cancel();
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  Future<void> _stopOutputs() {
    return Future.wait([_safeRun(_cancelVibration), _safeRun(_stopSound)]);
  }

  Future<void> _safeVibrate(Duration duration) async {
    try {
      await _vibrate(duration);
    } catch (_) {
      // Umpan balik perangkat bersifat tambahan; timer harus tetap berjalan.
    }
  }

  Future<void> _safeRun(BrewFeedbackAction action) async {
    try {
      await action();
    } catch (_) {
      // Umpan balik perangkat bersifat tambahan; timer harus tetap berjalan.
    }
  }
}
