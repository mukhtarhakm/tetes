import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../data/repositories/game_repo.dart';
import 'game_feedback.dart';
import 'steady_pour_control.dart';
import 'steady_pour_game.dart';

enum GamePrototypePhase {
  loading,
  selection,
  calibration,
  countdown,
  playing,
  paused,
  saving,
  result,
  saveError,
  unavailable,
}

class GamePrototypeController extends ChangeNotifier {
  GamePrototypeController({
    required this.userId,
    required this.repository,
    Stream<GyroscopeEvent>? events,
    GameFeedback? feedback,
  }) : _events =
           events ??
           gyroscopeEventStream(samplingPeriod: SensorInterval.uiInterval),
       _feedback = feedback ?? GameFeedback();

  final String userId;
  final GameRepository repository;
  final Stream<GyroscopeEvent> _events;
  final GameFeedback _feedback;

  GamePrototypePhase phase = GamePrototypePhase.loading;
  GamePrototypePhase? _phaseBeforePause;
  GameSensitivity sensitivity = GameSensitivity.medium;
  Map<int, BestGameScore> bestScores = {};
  GameState? game;
  PourPosition get position => game?.position ?? const PourPosition.center();
  double countdownSeconds = 3;
  StreamSubscription<GyroscopeEvent>? _subscription;
  Timer? _watchdog;
  DateTime? _lastTimestamp;
  bool _completionSaved = false;
  bool _disposed = false;

  String unavailableMessage =
      'Gyroscope tidak tersedia atau tidak mengirim data. Game tidak dapat dimainkan di perangkat ini.';

  Future<void> initialize() async {
    try {
      sensitivity = await repository.get(userId);
      bestScores = await repository.bestScores(userId);
      if (_disposed) return;
      phase = GamePrototypePhase.selection;
      notifyListeners();
      _subscribe();
    } catch (_) {
      _markUnavailable('Game tidak dapat dibuka. Coba lagi.');
    }
  }

  bool isUnlocked(int level) => level == 1 || bestScores.containsKey(level - 1);

  void selectLevel(GameLevel level) {
    if (phase != GamePrototypePhase.selection ||
        !gameLevels.contains(level) ||
        !isUnlocked(level.number)) {
      return;
    }
    game = GameState(level: level);
    _completionSaved = false;
    countdownSeconds = 3;
    phase = GamePrototypePhase.calibration;
    notifyListeners();
  }

  void calibrateAndStart() {
    if (phase != GamePrototypePhase.calibration || game == null) return;
    game = game!.withPosition(const PourPosition.center());
    _lastTimestamp = null;
    countdownSeconds = 3;
    phase = GamePrototypePhase.countdown;
    notifyListeners();
  }

  void returnToSelection() {
    if (phase == GamePrototypePhase.saving) return;
    _feedback.cancel();
    game = null;
    _completionSaved = false;
    phase = GamePrototypePhase.selection;
    _lastTimestamp = null;
    notifyListeners();
    _subscribe();
  }

  void retryLevel() {
    final level = game?.level;
    if (level == null || phase != GamePrototypePhase.result) return;
    _feedback.cancel();
    game = GameState(level: level);
    _completionSaved = false;
    phase = GamePrototypePhase.calibration;
    _lastTimestamp = null;
    notifyListeners();
    _subscribe();
  }

  void nextLevel() {
    final next = game?.level.number ?? 0;
    if (phase != GamePrototypePhase.result ||
        next >= gameLevels.length ||
        !isUnlocked(next + 1)) {
      return;
    }
    _feedback.cancel();
    game = GameState(level: gameLevels[next]);
    _completionSaved = false;
    phase = GamePrototypePhase.calibration;
    _lastTimestamp = null;
    notifyListeners();
    _subscribe();
  }

  Future<void> setSensitivity(GameSensitivity value) async {
    if (phase == GamePrototypePhase.unavailable) return;
    try {
      await repository.set(userId, value);
      if (_disposed) return;
      sensitivity = value;
      notifyListeners();
    } catch (_) {
      _markUnavailable('Sensitivitas tidak dapat disimpan. Coba lagi.');
    }
  }

  void _subscribe() {
    if (_disposed || _subscription != null) return;
    try {
      _subscription = _events.listen(
        _onEvent,
        onError: (_) => _markUnavailable(),
      );
      _resetWatchdog();
    } catch (_) {
      _markUnavailable();
    }
  }

  void _resetWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 2), _markUnavailable);
  }

  void _onEvent(GyroscopeEvent event) {
    if (_disposed ||
        phase == GamePrototypePhase.paused ||
        phase == GamePrototypePhase.unavailable) {
      return;
    }
    _resetWatchdog();
    final timestamp = event.timestamp;
    final previous = _lastTimestamp;
    _lastTimestamp = timestamp;
    if (previous == null) return;
    final rawDt = timestamp.difference(previous).inMicroseconds / 1000000;
    if (!rawDt.isFinite || rawDt <= 0) return;
    final dt = math.min(rawDt, maxSensorDeltaSeconds);

    if (phase == GamePrototypePhase.countdown) {
      countdownSeconds = math.max(0, countdownSeconds - dt);
      if (countdownSeconds == 0) phase = GamePrototypePhase.playing;
      notifyListeners();
      return;
    }
    if (phase != GamePrototypePhase.playing || game == null) return;
    final wasInside = game!.isInsideZone;
    final speed = mapGyroscopeToPour(event.x, event.y);
    game = advanceGame(
      game!,
      xRadiansPerSecond: speed.x,
      yRadiansPerSecond: speed.y,
      dtSeconds: dt,
      sensitivity: sensitivity,
    );
    if (wasInside &&
        !game!.isInsideZone &&
        game!.outcome == GameOutcome.playing) {
      _feedback.playExit();
    }
    if (game!.outcome != GameOutcome.playing) {
      _stopSensor();
      if (game!.outcome == GameOutcome.completed) {
        _feedback.playComplete();
        unawaited(_saveCompletion());
      } else {
        phase = GamePrototypePhase.result;
      }
    }
    notifyListeners();
  }

  Future<void> _saveCompletion() async {
    phase = GamePrototypePhase.saving;
    notifyListeners();
    try {
      if (!_completionSaved) {
        await repository.saveCompletion(userId, game!);
        _completionSaved = true;
      }
      bestScores = await repository.bestScores(userId);
      if (_disposed) return;
      if (phase == GamePrototypePhase.paused) {
        _phaseBeforePause = GamePrototypePhase.result;
      } else {
        phase = GamePrototypePhase.result;
      }
      notifyListeners();
    } catch (_) {
      if (_disposed) return;
      if (phase == GamePrototypePhase.paused) {
        _phaseBeforePause = GamePrototypePhase.saveError;
      } else {
        phase = GamePrototypePhase.saveError;
      }
      notifyListeners();
    }
  }

  void retrySave() {
    if (phase == GamePrototypePhase.saveError &&
        game?.outcome == GameOutcome.completed) {
      unawaited(_saveCompletion());
    }
  }

  void pause() {
    if (phase == GamePrototypePhase.paused ||
        phase == GamePrototypePhase.unavailable ||
        phase == GamePrototypePhase.loading) {
      return;
    }
    _phaseBeforePause = phase;
    phase = GamePrototypePhase.paused;
    _feedback.cancel();
    _stopSensor();
    notifyListeners();
  }

  void resume() {
    if (phase != GamePrototypePhase.paused) return;
    final previous = _phaseBeforePause;
    if (previous == GamePrototypePhase.selection ||
        previous == GamePrototypePhase.result ||
        previous == GamePrototypePhase.saveError ||
        previous == GamePrototypePhase.saving) {
      phase = previous!;
    } else {
      phase = GamePrototypePhase.calibration;
      game = game?.withPosition(const PourPosition.center());
    }
    _lastTimestamp = null;
    notifyListeners();
    if (phase == GamePrototypePhase.selection ||
        phase == GamePrototypePhase.calibration) {
      _subscribe();
    }
  }

  void _markUnavailable([String? message]) {
    if (_disposed || phase == GamePrototypePhase.paused) return;
    if (message != null) unavailableMessage = message;
    phase = GamePrototypePhase.unavailable;
    _feedback.cancel();
    _stopSensor();
    notifyListeners();
  }

  void _stopSensor() {
    _watchdog?.cancel();
    _watchdog = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _lastTimestamp = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _feedback.dispose();
    _stopSensor();
    super.dispose();
  }
}
