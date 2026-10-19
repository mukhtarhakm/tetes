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

  test('pindah otomatis tepat saat hitung mundur nol', () {
    controller.start();
    time.seconds = 39;

    expect(controller.reconcile(), BrewSessionAction.ignored);
    expect(controller.activeStageIndex, 0);

    time.seconds = 40;
    expect(controller.reconcile(), BrewSessionAction.stageAdvanced);
    expect(controller.activeStageIndex, 1);
    expect(controller.actualStages[0]!.actualStartS, 0);
    expect(controller.actualStages[0]!.actualDurationS, 40);
    expect(controller.countdownSeconds, 30);
  });

  test(
    'tombol berikutnya menutup lebih awal dan menggeser tenggat berikutnya',
    () {
      controller.start();
      time.seconds = 25;

      expect(controller.nextStage(), BrewSessionAction.stageAdvanced);

      expect(controller.actualStages[0]!.actualStartS, 0);
      expect(controller.actualStages[0]!.actualDurationS, 25);
      expect(controller.activeStageIndex, 1);
      expect(controller.countdownSeconds, 30);

      time.seconds = 54;
      expect(controller.reconcile(), BrewSessionAction.ignored);
      expect(controller.activeStageIndex, 1);

      time.seconds = 55;
      expect(controller.reconcile(), BrewSessionAction.stageAdvanced);
      expect(controller.activeStageIndex, 2);
      expect(controller.actualStages[1]!.actualStartS, 25);
      expect(controller.actualStages[1]!.actualDurationS, 30);
    },
  );

  test('Selesai lebih awal mencatat total waktu dan drawdown null', () {
    controller.start();
    time.seconds = 40;
    controller.nextStage();
    time.seconds = 70;
    controller.nextStage();
    time.seconds = 85;

    expect(controller.finish(), BrewSessionAction.completed);

    final result = controller.result!;
    expect(result.totalTimeS, 85);
    expect(result.stages, hasLength(3));
    expect(result.stages.last.actualStartS, 70);
    expect(result.stages.last.actualDurationS, 15);
    expect(result.stages.every((stage) => stage.drawdownS == null), isTrue);
  });

  test('tahap terakhir menyelesaikan sesi otomatis tepat saat nol', () {
    controller.start();
    time.seconds = 40;
    expect(controller.reconcile(), BrewSessionAction.stageAdvanced);
    time.seconds = 70;
    expect(controller.reconcile(), BrewSessionAction.stageAdvanced);
    expect(controller.activeStageIndex, 2);

    time.seconds = 100;
    expect(controller.reconcile(), BrewSessionAction.completed);
    expect(controller.activeStageIndex, 2);
    expect(controller.status, BrewSessionStatus.completed);
    expect(controller.result!.totalTimeS, 100);
    expect(controller.result!.stages.last.actualDurationS, 30);
    expect(
      controller.result!.stages.every((stage) => stage.drawdownS == null),
      isTrue,
    );
    expect(controller.reconcile(), BrewSessionAction.ignored);
  });

  test('kembali dari latar belakang melewati dua tahap pada tenggatnya', () {
    controller.start();
    time.seconds = 75;

    expect(controller.reconcile(), BrewSessionAction.stageAdvanced);
    expect(controller.activeStageIndex, 2);
    expect(controller.actualStages[0]!.actualStartS, 0);
    expect(controller.actualStages[0]!.actualDurationS, 40);
    expect(controller.actualStages[1]!.actualStartS, 40);
    expect(controller.actualStages[1]!.actualDurationS, 30);
    expect(controller.activeStageElapsedSeconds, 5);
    expect(controller.reconcile(), BrewSessionAction.ignored);
  });

  test(
    'kembali setelah tenggat terakhir selesai pada tenggat, bukan waktu kini',
    () {
      controller.start();
      time.seconds = 125;

      expect(controller.reconcile(), BrewSessionAction.completed);

      final result = controller.result!;
      expect(result.totalTimeS, 100);
      expect(result.stages[0].actualDurationS, 40);
      expect(result.stages[1].actualStartS, 40);
      expect(result.stages[1].actualDurationS, 30);
      expect(result.stages[2].actualStartS, 70);
      expect(result.stages[2].actualDurationS, 30);
      expect(result.stages.every((stage) => stage.drawdownS == null), isTrue);
    },
  );

  test('goyang memulai sebelum sesi dan tidak memajukan setelah berjalan', () {
    expect(controller.handleShake(), BrewSessionAction.started);
    expect(controller.activeStageIndex, 0);
    time.seconds = 50;

    expect(controller.handleShake(), BrewSessionAction.ignored);
    expect(controller.activeStageIndex, 0);
    expect(controller.elapsedSeconds, 50);
    expect(controller.actualStages[0], isNull);
    expect(controller.status, BrewSessionStatus.running);
    expect(controller.result, isNull);
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
