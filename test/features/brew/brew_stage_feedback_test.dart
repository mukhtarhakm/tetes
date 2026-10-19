import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/brew/services/brew_stage_feedback.dart';

void main() {
  test(
    'setiap pergantian memakai satu pola getar dan suara yang sama',
    () async {
      final durations = <Duration>[];
      var transitionSounds = 0;
      final feedback = _feedback(
        vibrate: (duration) async => durations.add(duration),
        playTransitionSound: () async => transitionSounds++,
      );

      await feedback.playTransition();
      await feedback.playTransition();

      expect(durations, [
        stageTransitionVibrationDuration,
        stageTransitionVibrationDuration,
      ]);
      expect(transitionSounds, 2);
    },
  );

  test('akhir sesi memakai getar lebih panjang dan suara berbeda', () async {
    final durations = <Duration>[];
    final delays = <Duration>[];
    var transitionSounds = 0;
    var completionSounds = 0;
    final feedback = _feedback(
      vibrate: (duration) async => durations.add(duration),
      playTransitionSound: () async => transitionSounds++,
      playCompletionSound: () async => completionSounds++,
      delay: (duration) async => delays.add(duration),
    );

    await feedback.playCompleted();

    expect(durations, [sessionCompletionVibrationDuration]);
    expect(
      sessionCompletionVibrationDuration,
      greaterThan(stageTransitionVibrationDuration),
    );
    expect(transitionSounds, 0);
    expect(completionSounds, 1);
    expect(delays, [sessionCompletionSoundDuration]);
  });

  test('feedback lama dibatalkan ketika tahap berubah', () async {
    final completionDelay = Completer<void>();
    final durations = <Duration>[];
    var vibrationCancels = 0;
    var soundStops = 0;
    final feedback = _feedback(
      vibrate: (duration) async => durations.add(duration),
      cancelVibration: () async => vibrationCancels++,
      stopSound: () async => soundStops++,
      delay: (_) => completionDelay.future,
    );

    final completion = feedback.playCompleted();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final transition = feedback.playTransition();
    completionDelay.complete();
    await Future.wait([completion, transition]);

    expect(durations, [
      sessionCompletionVibrationDuration,
      stageTransitionVibrationDuration,
    ]);
    expect(vibrationCancels, greaterThanOrEqualTo(2));
    expect(soundStops, greaterThanOrEqualTo(2));
  });

  test('menutup layar membatalkan getar dan suara', () async {
    var vibrationCancels = 0;
    var soundStops = 0;
    final feedback = _feedback(
      cancelVibration: () async => vibrationCancels++,
      stopSound: () async => soundStops++,
    );

    feedback.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(vibrationCancels, 1);
    expect(soundStops, 1);
  });
}

BrewStageFeedback _feedback({
  BrewFeedbackVibrate? vibrate,
  BrewFeedbackAction? cancelVibration,
  BrewFeedbackAction? playTransitionSound,
  BrewFeedbackAction? playCompletionSound,
  BrewFeedbackAction? stopSound,
  BrewFeedbackDelay? delay,
}) {
  return BrewStageFeedback(
    vibrate: vibrate ?? (_) async {},
    cancelVibration: cancelVibration ?? () async {},
    playTransitionSound: playTransitionSound ?? () async {},
    playCompletionSound: playCompletionSound ?? () async {},
    stopSound: stopSound ?? () async {},
    delay: delay ?? (_) async {},
  );
}
