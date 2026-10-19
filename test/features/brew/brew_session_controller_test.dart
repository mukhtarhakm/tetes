import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/services/brew_session_hardware.dart';
import 'package:tetes/features/brew/state/brew_session_controller.dart';

void main() {
  late FakeTimeSource time;
  late BrewSessionController controller;

  setUp(() {
    time = FakeTimeSource();
    controller = BrewSessionController(
      plan: BrewCalculator.createDefault(beanId: 'bean-1'),
      timeSource: time,
    );
  });

  test('tahap berjalan berurutan sesuai rencana', () {
    expect(controller.start(), BrewSessionAction.started);
    time.seconds = 45;
    expect(controller.nextStage(), BrewSessionAction.stageAdvanced);
    expect(controller.activeStageIndex, 1);
    expect(controller.activeStage.name.databaseValue, 'pouring_2');
    time.seconds = 80;
    expect(controller.nextStage(), BrewSessionAction.stageAdvanced);
    expect(controller.activeStageIndex, 2);
    expect(controller.activeStage.name.databaseValue, 'pouring_3');
    expect(controller.actualStages[1]!.actualStartS, 45);
    expect(controller.actualStages[1]!.actualDurationS, 35);
  });

  test('tombol berikutnya menutup durasi tahap sebelumnya', () {
    controller.start();
    time.seconds = 47;

    controller.nextStage();

    expect(controller.actualStages[0]!.actualStartS, 0);
    expect(controller.actualStages[0]!.actualDurationS, 47);
    expect(controller.activeStageIndex, 1);
  });

  test('Air habis mengisi drawdown dan total waktu', () {
    controller.start();
    time.seconds = 45;
    controller.nextStage();
    time.seconds = 80;
    controller.nextStage();
    time.seconds = 120;

    expect(controller.finish(), BrewSessionAction.completed);

    final result = controller.result!;
    expect(result.totalTimeS, 120);
    expect(result.stages, hasLength(3));
    expect(result.stages.last.actualStartS, 80);
    expect(result.stages.last.actualDurationS, 40);
    expect(result.stages.last.drawdownS, 10);
  });

  test('countdown nol memberi tanda tanpa mengganti tahap', () {
    controller.start();
    time.seconds = 40;

    expect(controller.pollTarget(), BrewSessionAction.targetReached);
    expect(controller.activeStageIndex, 0);
    expect(controller.status, BrewSessionStatus.running);
    expect(controller.pollTarget(), BrewSessionAction.ignored);
  });

  test('goyang memulai sebelum sesi dan tidak memajukan setelah berjalan', () {
    expect(controller.handleShake(), BrewSessionAction.started);
    expect(controller.activeStageIndex, 0);
    time.seconds = 50;

    expect(controller.handleShake(), BrewSessionAction.ignored);
    expect(controller.activeStageIndex, 0);
    expect(controller.elapsedSeconds, 50);
    expect(controller.actualStages[0], isNull);
  });

  test('batal tidak menghasilkan hasil', () {
    controller.start();
    time.seconds = 25;

    expect(controller.cancel(), BrewSessionAction.cancelled);
    expect(controller.status, BrewSessionStatus.cancelled);
    expect(controller.result, isNull);
  });

  test('cooldown goyang memakai jam yang disuntikkan', () {
    var now = DateTime.utc(2026, 10, 19);
    final gate = ShakeGate(clock: () => now);

    expect(gate.shouldTrigger(x: 27, y: 0, z: 0), isTrue);
    now = now.add(const Duration(seconds: 1));
    expect(gate.shouldTrigger(x: 27, y: 0, z: 0), isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(gate.shouldTrigger(x: 27, y: 0, z: 0), isTrue);
  });
}

class FakeTimeSource implements ElapsedTimeSource {
  int seconds = 0;
  bool running = false;

  @override
  Duration get elapsed => Duration(seconds: seconds);

  @override
  void reset() {
    seconds = 0;
  }

  @override
  void start() {
    running = true;
  }

  @override
  void stop() {
    running = false;
  }
}
