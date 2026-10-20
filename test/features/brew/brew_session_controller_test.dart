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

  test('tahap berganti tepat pada target mulai dan masuk drawdown', () {
    expect(controller.start(), BrewSessionAction.started);
    time.advance(39);
    expect(controller.reconcile(), BrewSessionAction.ignored);
    expect(controller.activeStageIndex, 0);

    time.advance(1);
    expect(controller.reconcile(), BrewSessionAction.stageAdvanced);
    expect(controller.activeStageIndex, 1);
    expect(controller.countdownSeconds, 30);

    time.advance(30);
    expect(controller.reconcile(), BrewSessionAction.stageAdvanced);
    expect(controller.activeStageIndex, 2);
    time.advance(30);
    expect(controller.reconcile(), BrewSessionAction.drawdownStarted);
    expect(controller.isDrawdown, isTrue);
    expect(controller.drawdownElapsedSeconds, 0);
    expect(controller.result, isNull);
  });

  test('Air habis mencatat drawdown dan total waktu aktif', () {
    controller.start();
    time.advance(100);
    controller.reconcile();
    time.advance(35);

    expect(controller.finishDrawdown(), BrewSessionAction.completed);
    expect(controller.result!.drawdownS, 35);
    expect(controller.result!.totalTimeS, 135);
    expect(controller.result!.plan.stages, hasLength(3));
    expect(controller.finishDrawdown(), BrewSessionAction.ignored);
  });

  test('Lewati menyimpan drawdown null dan total waktu saat ditekan', () {
    controller.start();
    time.advance(112);
    controller.reconcile();

    expect(controller.skipDrawdown(), BrewSessionAction.completed);
    expect(controller.result!.drawdownS, isNull);
    expect(controller.result!.totalTimeS, 112);
  });

  test('batas drawdown 10 menit menutup tepat pada batas', () {
    controller.start();
    time.advance(699);
    expect(controller.reconcile(), BrewSessionAction.drawdownStarted);
    time.advance(1);
    expect(controller.reconcile(), BrewSessionAction.completed);
    expect(controller.result!.drawdownS, isNull);
    expect(controller.result!.totalTimeS, 700);
    expect(time.running, isFalse);
  });

  test('kembali terlambat dari latar belakang memakai batas 10 menit', () {
    controller.start();
    time.advance(725);

    expect(controller.reconcile(), BrewSessionAction.completed);
    expect(controller.result!.totalTimeS, 700);
    expect(controller.result!.drawdownS, isNull);
  });

  test('jeda menggeser tahap dan tidak masuk total waktu', () {
    controller.start();
    time.advance(20);
    expect(controller.pause(), BrewSessionAction.paused);
    time.advance(50);
    expect(controller.elapsedSeconds, 20);
    expect(controller.reconcile(), BrewSessionAction.ignored);
    expect(controller.resume(), BrewSessionAction.resumed);

    time.advance(19);
    expect(controller.reconcile(), BrewSessionAction.ignored);
    time.advance(1);
    expect(controller.reconcile(), BrewSessionAction.stageAdvanced);
    expect(time.wallSeconds, 90);
    expect(controller.elapsedSeconds, 40);
    time.advance(60);
    expect(controller.reconcile(), BrewSessionAction.drawdownStarted);
    expect(controller.skipDrawdown(), BrewSessionAction.completed);
    expect(controller.result!.totalTimeS, 100);
  });

  test('jeda saat drawdown tidak menambah drawdown atau total', () {
    controller.start();
    time.advance(105);
    controller.reconcile();
    expect(controller.pause(), BrewSessionAction.paused);
    time.advance(100);
    expect(controller.drawdownElapsedSeconds, 5);
    expect(controller.finishDrawdown(), BrewSessionAction.ignored);
    expect(controller.resume(), BrewSessionAction.resumed);
    time.advance(20);
    expect(controller.finishDrawdown(), BrewSessionAction.completed);
    expect(controller.result!.drawdownS, 25);
    expect(controller.result!.totalTimeS, 125);
  });

  test('kembali setelah dua tahap terlewat langsung ke tahap sesuai waktu', () {
    controller.start();
    time.advance(75);
    expect(controller.reconcile(), BrewSessionAction.stageAdvanced);
    expect(controller.activeStageIndex, 2);
    expect(controller.activeStageElapsedSeconds, 5);
    expect(controller.reconcile(), BrewSessionAction.ignored);
    time.advance(50);
    expect(controller.reconcile(), BrewSessionAction.drawdownStarted);
    expect(controller.drawdownElapsedSeconds, 25);
  });

  test('goyang hanya memulai sesi', () {
    expect(controller.handleShake(), BrewSessionAction.started);
    time.advance(50);
    expect(controller.handleShake(), BrewSessionAction.ignored);
    expect(controller.activeStageIndex, 0);
    controller.pause();
    expect(controller.handleShake(), BrewSessionAction.ignored);
    controller.resume();
    time.advance(50);
    controller.reconcile();
    expect(controller.handleShake(), BrewSessionAction.ignored);
    expect(controller.isDrawdown, isTrue);
  });

  test('batal tidak menghasilkan hasil', () {
    controller.start();
    time.advance(25);
    expect(controller.cancel(), BrewSessionAction.cancelled);
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
  int wallSeconds = 0;
  bool running = false;

  void advance(int amount) {
    wallSeconds += amount;
    if (running) {
      seconds += amount;
    }
  }

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
