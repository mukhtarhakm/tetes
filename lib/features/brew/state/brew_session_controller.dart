import 'dart:math' as math;

import '../brew_plan.dart';
import '../brew_session_result.dart';

enum BrewSessionStatus {
  ready,
  running,
  drawdown,
  paused,
  completed,
  cancelled,
}

enum BrewSessionAction {
  ignored,
  started,
  stageAdvanced,
  drawdownStarted,
  paused,
  resumed,
  completed,
  cancelled,
}

abstract interface class ElapsedTimeSource {
  Duration get elapsed;

  void start();

  void stop();

  void reset();
}

class StopwatchTimeSource implements ElapsedTimeSource {
  StopwatchTimeSource({Stopwatch? stopwatch})
    : _stopwatch = stopwatch ?? Stopwatch();

  final Stopwatch _stopwatch;

  @override
  Duration get elapsed => _stopwatch.elapsed;

  @override
  void reset() => _stopwatch.reset();

  @override
  void start() => _stopwatch.start();

  @override
  void stop() => _stopwatch.stop();
}

class BrewSessionController {
  BrewSessionController({required this.plan, ElapsedTimeSource? timeSource})
    : _timeSource = timeSource ?? StopwatchTimeSource();

  static const drawdownLimitSeconds = 600;

  final BrewPlan plan;
  final ElapsedTimeSource _timeSource;

  BrewSessionStatus _status = BrewSessionStatus.ready;
  BrewSessionStatus? _pausedFrom;
  int _activeStageIndex = 0;
  BrewSessionResult? _result;

  BrewSessionStatus get status => _status;
  int get activeStageIndex => _activeStageIndex;
  BrewStage get activeStage => plan.stages[_activeStageIndex];
  BrewSessionResult? get result => _result;
  bool get isDrawdown =>
      _status == BrewSessionStatus.drawdown ||
      (_status == BrewSessionStatus.paused &&
          _pausedFrom == BrewSessionStatus.drawdown);

  int get elapsedSeconds =>
      _result?.totalTimeS ?? _timeSource.elapsed.inSeconds;

  int get activeStageElapsedSeconds =>
      math.max(0, elapsedSeconds - activeStage.startSeconds);

  int get countdownSeconds =>
      math.max(0, activeStage.endSeconds - elapsedSeconds);

  int get drawdownElapsedSeconds =>
      math.max(0, elapsedSeconds - plan.totalTimeSeconds);

  BrewSessionAction start() {
    if (_status != BrewSessionStatus.ready || plan.stages.isEmpty) {
      return BrewSessionAction.ignored;
    }
    _timeSource.reset();
    _timeSource.start();
    _status = BrewSessionStatus.running;
    return BrewSessionAction.started;
  }

  BrewSessionAction handleShake() =>
      _status == BrewSessionStatus.ready ? start() : BrewSessionAction.ignored;

  BrewSessionAction reconcile() {
    if (_status != BrewSessionStatus.running &&
        _status != BrewSessionStatus.drawdown) {
      return BrewSessionAction.ignored;
    }

    final now = elapsedSeconds;
    if (now >= plan.totalTimeSeconds + drawdownLimitSeconds) {
      return _complete(plan.totalTimeSeconds + drawdownLimitSeconds, null);
    }

    if (now >= plan.totalTimeSeconds) {
      if (_status == BrewSessionStatus.drawdown) {
        return BrewSessionAction.ignored;
      }
      _activeStageIndex = plan.stages.length - 1;
      _status = BrewSessionStatus.drawdown;
      return BrewSessionAction.drawdownStarted;
    }

    var advanced = false;
    while (_activeStageIndex < plan.stages.length - 1 &&
        now >= plan.stages[_activeStageIndex + 1].startSeconds) {
      _activeStageIndex++;
      advanced = true;
    }
    return advanced
        ? BrewSessionAction.stageAdvanced
        : BrewSessionAction.ignored;
  }

  BrewSessionAction pause() {
    if (_status != BrewSessionStatus.running &&
        _status != BrewSessionStatus.drawdown) {
      return BrewSessionAction.ignored;
    }
    if (reconcile() == BrewSessionAction.completed) {
      return BrewSessionAction.completed;
    }
    _pausedFrom = _status;
    _timeSource.stop();
    _status = BrewSessionStatus.paused;
    return BrewSessionAction.paused;
  }

  BrewSessionAction resume() {
    if (_status != BrewSessionStatus.paused) {
      return BrewSessionAction.ignored;
    }
    _status = _pausedFrom!;
    _pausedFrom = null;
    _timeSource.start();
    return BrewSessionAction.resumed;
  }

  BrewSessionAction finishDrawdown() => _endDrawdown(recordDrawdown: true);

  BrewSessionAction skipDrawdown() => _endDrawdown(recordDrawdown: false);

  BrewSessionAction _endDrawdown({required bool recordDrawdown}) {
    if (_status != BrewSessionStatus.drawdown) {
      return BrewSessionAction.ignored;
    }
    if (reconcile() == BrewSessionAction.completed) {
      return BrewSessionAction.completed;
    }
    final endSeconds = elapsedSeconds;
    return _complete(
      endSeconds,
      recordDrawdown ? endSeconds - plan.totalTimeSeconds : null,
    );
  }

  BrewSessionAction _complete(int endSeconds, int? drawdownSeconds) {
    _timeSource.stop();
    _status = BrewSessionStatus.completed;
    _result = BrewSessionResult(
      plan: plan,
      drawdownS: drawdownSeconds,
      totalTimeS: endSeconds,
    );
    return BrewSessionAction.completed;
  }

  BrewSessionAction cancel() {
    if (_status == BrewSessionStatus.completed ||
        _status == BrewSessionStatus.cancelled) {
      return BrewSessionAction.ignored;
    }
    _timeSource.stop();
    _status = BrewSessionStatus.cancelled;
    _result = null;
    return BrewSessionAction.cancelled;
  }
}
