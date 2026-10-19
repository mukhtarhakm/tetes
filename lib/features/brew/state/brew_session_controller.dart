import 'dart:math' as math;

import '../brew_plan.dart';
import '../brew_session_result.dart';

enum BrewSessionStatus { ready, running, completed, cancelled }

enum BrewSessionAction {
  ignored,
  started,
  stageAdvanced,
  targetReached,
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
    : _timeSource = timeSource ?? StopwatchTimeSource(),
      _actualStages = List.generate(
        plan.stages.length,
        (index) => _MutableStageActual(),
      );

  final BrewPlan plan;
  final ElapsedTimeSource _timeSource;
  final List<_MutableStageActual> _actualStages;
  final Set<int> _targetCueSentForStage = {};

  BrewSessionStatus _status = BrewSessionStatus.ready;
  int _activeStageIndex = 0;
  BrewSessionResult? _result;

  BrewSessionStatus get status => _status;
  int get activeStageIndex => _activeStageIndex;
  BrewStage get activeStage => plan.stages[_activeStageIndex];
  BrewSessionResult? get result => _result;

  int get elapsedSeconds {
    if (_result != null) {
      return _result!.totalTimeS;
    }
    return _timeSource.elapsed.inSeconds;
  }

  int get activeStageElapsedSeconds {
    if (_status != BrewSessionStatus.running) {
      return 0;
    }
    final start = _actualStages[_activeStageIndex].actualStartS;
    return start == null ? 0 : math.max(0, elapsedSeconds - start);
  }

  int get countdownSeconds {
    return activeStage.durationSeconds - activeStageElapsedSeconds;
  }

  List<BrewStageActual?> get actualStages {
    return List.unmodifiable(
      List.generate(_actualStages.length, (index) {
        final actual = _actualStages[index];
        final start = actual.actualStartS;
        final duration = actual.actualDurationS;
        if (start == null || duration == null) {
          return null;
        }
        return BrewStageActual(
          position: plan.stages[index].position,
          name: plan.stages[index].name,
          actualStartS: start,
          actualDurationS: duration,
          drawdownS: actual.drawdownS,
        );
      }),
    );
  }

  BrewSessionAction start() {
    if (_status != BrewSessionStatus.ready || plan.stages.isEmpty) {
      return BrewSessionAction.ignored;
    }
    _timeSource.reset();
    _timeSource.start();
    _actualStages.first.actualStartS = 0;
    _status = BrewSessionStatus.running;
    return BrewSessionAction.started;
  }

  BrewSessionAction handleShake() {
    if (_status != BrewSessionStatus.ready) {
      return BrewSessionAction.ignored;
    }
    return start();
  }

  BrewSessionAction pollTarget() {
    if (_status != BrewSessionStatus.running ||
        _targetCueSentForStage.contains(_activeStageIndex) ||
        countdownSeconds > 0) {
      return BrewSessionAction.ignored;
    }
    _targetCueSentForStage.add(_activeStageIndex);
    return BrewSessionAction.targetReached;
  }

  BrewSessionAction nextStage() {
    if (_status != BrewSessionStatus.running ||
        _activeStageIndex >= plan.stages.length - 1) {
      return BrewSessionAction.ignored;
    }
    final now = elapsedSeconds;
    _closeActiveStage(now);
    _activeStageIndex++;
    _actualStages[_activeStageIndex].actualStartS = now;
    return BrewSessionAction.stageAdvanced;
  }

  BrewSessionAction finish() {
    if (_status != BrewSessionStatus.running ||
        _activeStageIndex != plan.stages.length - 1) {
      return BrewSessionAction.ignored;
    }
    final now = elapsedSeconds;
    _closeActiveStage(now);
    final lastActual = _actualStages.last;
    lastActual.drawdownS = math.max(
      0,
      lastActual.actualDurationS! - plan.stages.last.durationSeconds,
    );
    _timeSource.stop();
    _status = BrewSessionStatus.completed;
    _result = BrewSessionResult(
      plan: plan,
      stages: List.unmodifiable(
        List.generate(_actualStages.length, (index) {
          final actual = _actualStages[index];
          return BrewStageActual(
            position: plan.stages[index].position,
            name: plan.stages[index].name,
            actualStartS: actual.actualStartS!,
            actualDurationS: actual.actualDurationS!,
            drawdownS: actual.drawdownS,
          );
        }),
      ),
      totalTimeS: now,
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

  void _closeActiveStage(int now) {
    final actual = _actualStages[_activeStageIndex];
    final start = actual.actualStartS!;
    actual.actualDurationS = math.max(0, now - start);
  }
}

class _MutableStageActual {
  int? actualStartS;
  int? actualDurationS;
  int? drawdownS;
}
