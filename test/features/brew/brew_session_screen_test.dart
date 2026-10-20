import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tetes/app/theme/tokens.dart';
import 'package:tetes/core/ui/app_button.dart';
import 'package:tetes/core/ui/app_card.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/brew_plan.dart';
import 'package:tetes/features/brew/screens/brew_result_placeholder_screen.dart';
import 'package:tetes/features/brew/screens/brew_session_screen.dart';
import 'package:tetes/features/brew/services/brew_session_hardware.dart';
import 'package:tetes/features/brew/services/brew_stage_feedback.dart';
import 'package:tetes/features/brew/state/brew_session_controller.dart';

void main() {
  testWidgets('menampilkan keadaan memuat sebelum inisialisasi', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_screen(BrewCalculator.createDefault(beanId: 'bean-1'))),
    );

    expect(find.text('Menyiapkan sesi seduh...'), findsOneWidget);
  });

  testWidgets('rencana tanpa tahap menampilkan keadaan kosong', (tester) async {
    await tester.pumpWidget(_app(_screen(_emptyPlan())));
    await tester.pump();

    expect(find.text('Rencana seduh kosong'), findsOneWidget);
    expect(find.text('Kembali'), findsOneWidget);
  });

  testWidgets('rencana tidak valid menampilkan keadaan galat', (tester) async {
    final valid = BrewCalculator.createDefault(beanId: 'bean-1');
    final invalid = valid.copyWith(
      stages: [valid.stages.first.copyWith(durationSeconds: 1)],
      pouringCount: 1,
    );
    await tester.pumpWidget(_app(_screen(invalid)));
    await tester.pump();

    expect(find.text('Sesi seduh tidak dapat disiapkan.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('keadaan berhasil menampilkan tahap aktif dan tombol mulai', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_screen(BrewCalculator.createDefault(beanId: 'bean-1'))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Siap memulai'), findsOneWidget);
    expect(find.text('Waktu total'), findsOneWidget);
    expect(find.text('Urutan tahap'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppCard && widget.backgroundColor == AppColors.stage1,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppCard && widget.backgroundColor == AppColors.stage1Soft,
      ),
      findsOneWidget,
    );
    expect(_animatedBackground(AppColors.stage1), findsOneWidget);
    expect(_colorMarker(AppColors.stage2), findsOneWidget);
    expect(_colorMarker(AppColors.stage3), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Mulai timer'), findsOneWidget);
    expect(find.text('Tahap berikutnya'), findsNothing);
  });

  testWidgets('tombol batal selalu meminta konfirmasi', (tester) async {
    await tester.pumpWidget(
      _app(_screen(BrewCalculator.createDefault(beanId: 'bean-1'))),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Batalkan sesi'));
    await tester.tap(find.text('Batalkan sesi'));
    await tester.pumpAndSettle();

    expect(find.text('Batalkan sesi?'), findsOneWidget);
    expect(find.text('Waktu yang sudah dicatat akan dibuang.'), findsOneWidget);
    expect(find.text('Lanjut seduh'), findsOneWidget);
  });

  testWidgets('drawdown menampilkan Air habis dan Lewati', (tester) async {
    final time = _FakeTimeSource();
    await tester.pumpWidget(
      _app(
        _screen(
          BrewCalculator.createDefault(beanId: 'bean-1'),
          timeSource: time,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pump();
    await tester.tap(find.text('Mulai timer'));
    await tester.pump();

    time.seconds = 40;
    await tester.pump(sessionUiRefreshInterval);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppCard && widget.backgroundColor == AppColors.stage2,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppCard && widget.backgroundColor == AppColors.stage2Soft,
      ),
      findsOneWidget,
    );
    expect(_animatedBackground(AppColors.stage2), findsOneWidget);
    time.seconds = 70;
    await tester.pump(sessionUiRefreshInterval);
    time.seconds = 100;
    await tester.pump(sessionUiRefreshInterval);
    final finishButton = find.widgetWithText(AppButton, 'Air habis');
    await tester.ensureVisible(finishButton);

    expect(finishButton, findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);
    expect(find.text('Tahap berikutnya'), findsNothing);
    expect(find.text('Selesai'), findsWidgets);
  });

  testWidgets('batas drawdown otomatis membuka placeholder hasil', (
    tester,
  ) async {
    final time = _FakeTimeSource();
    await tester.pumpWidget(
      _app(
        _screen(
          BrewCalculator.createDefault(beanId: 'bean-1'),
          timeSource: time,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pump();
    await tester.tap(find.text('Mulai timer'));
    await tester.pump();

    time.seconds = 700;
    await tester.pump(sessionUiRefreshInterval);
    await tester.pumpAndSettle();

    expect(find.text('Hasil seduh'), findsWidgets);
    expect(find.byType(BrewResultPlaceholderScreen), findsOneWidget);
  });

  testWidgets('Air habis membawa drawdown dan total ke hasil', (tester) async {
    final time = _FakeTimeSource();
    await tester.pumpWidget(
      _app(
        _screen(
          BrewCalculator.createDefault(beanId: 'bean-1'),
          timeSource: time,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pump();
    await tester.tap(find.text('Mulai timer'));
    await tester.pump();
    time.seconds = 135;
    await tester.pump(sessionUiRefreshInterval);
    await tester.ensureVisible(find.text('Air habis'));
    await tester.tap(find.text('Air habis'));
    await tester.pumpAndSettle();

    expect(find.byType(BrewResultPlaceholderScreen), findsOneWidget);
  });

  testWidgets('Lewati membawa drawdown null ke hasil', (tester) async {
    final time = _FakeTimeSource();
    await tester.pumpWidget(
      _app(
        _screen(
          BrewCalculator.createDefault(beanId: 'bean-1'),
          timeSource: time,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pump();
    await tester.tap(find.text('Mulai timer'));
    await tester.pump();
    time.seconds = 112;
    await tester.pump(sessionUiRefreshInterval);
    await tester.ensureVisible(find.text('Lewati'));
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();

    expect(find.byType(BrewResultPlaceholderScreen), findsOneWidget);
  });

  testWidgets('jeda menghentikan timer dan umpan balik', (tester) async {
    final time = _FakeTimeSource();
    var sounds = 0;
    final feedback = _feedback(onTransition: () => sounds++);
    await tester.pumpWidget(
      _app(
        _screen(
          BrewCalculator.createDefault(beanId: 'bean-1'),
          timeSource: time,
          feedback: feedback,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pump();
    await tester.tap(find.text('Mulai timer'));
    await tester.pump();
    expect(sounds, 1);

    time.advance(20);
    await tester.tap(find.text('Jeda'));
    await tester.pump();
    time.advance(50);
    await tester.pump(sessionUiRefreshInterval);
    expect(time.seconds, 20);
    expect(sounds, 1);
    await tester.tap(find.text('Lanjut'));
    await tester.pump();
    time.advance(20);
    await tester.pump(sessionUiRefreshInterval);
    expect(sounds, 2);
  });

  testWidgets('kembali setelah tahap terlewat tanpa memutar umpan balik', (
    tester,
  ) async {
    final time = _FakeTimeSource();
    var sounds = 0;
    final feedback = _feedback(onTransition: () => sounds++);
    await tester.pumpWidget(
      _app(
        _screen(
          BrewCalculator.createDefault(beanId: 'bean-1'),
          timeSource: time,
          feedback: feedback,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pump();
    await tester.tap(find.text('Mulai timer'));
    await tester.pump();
    expect(sounds, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    time.seconds = 75;
    await tester.pump(sessionUiRefreshInterval);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(sounds, 1);
    expect(_animatedBackground(AppColors.stage3), findsOneWidget);
  });
}

Widget _screen(
  BrewPlan plan, {
  _FakeTimeSource? timeSource,
  BrewStageFeedback? feedback,
}) {
  return BrewSessionScreen(
    plan: plan,
    timeSource: timeSource ?? _FakeTimeSource(),
    shakeDetector: BrewShakeDetector(
      events: const Stream<AccelerometerEvent>.empty(),
    ),
    wakeLock: const _FakeWakeLock(),
    feedback: feedback ?? _feedback(),
  );
}

BrewStageFeedback _feedback({void Function()? onTransition}) =>
    BrewStageFeedback(
      vibrate: (_) async {},
      cancelVibration: () async {},
      playTransitionSound: () async => onTransition?.call(),
      playCompletionSound: () async {},
      stopSound: () async {},
      delay: (_) async {},
    );

Finder _animatedBackground(Color color) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is AnimatedContainer &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).color == color,
  );
}

Finder _colorMarker(Color color) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).color == color,
  );
}

Widget _app(Widget home) {
  return MaterialApp(home: home);
}

BrewPlan _emptyPlan() {
  return const BrewPlan(
    beanId: 'bean-1',
    doseG: 15,
    ratio: 16,
    waterTempC: 92,
    grind: Grind.sedang,
    pouringCount: 0,
    stages: [],
  );
}

class _FakeTimeSource implements ElapsedTimeSource {
  int seconds = 0;
  bool running = false;

  void advance(int amount) {
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
  void start() => running = true;

  @override
  void stop() => running = false;
}

class _FakeWakeLock implements BrewWakeLock {
  const _FakeWakeLock();

  @override
  Future<void> disable() async {}

  @override
  Future<void> enable() async {}
}
