import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tetes/app/theme/tokens.dart';
import 'package:tetes/core/ui/app_button.dart';
import 'package:tetes/core/ui/app_card.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/brew_plan.dart';
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

  testWidgets('keadaan berhasil menampilkan tahap aktif dan tombol manual', (
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

  testWidgets('tahap terakhir menampilkan tombol Selesai', (tester) async {
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
    final finishButton = find.widgetWithText(AppButton, 'Selesai');
    await tester.ensureVisible(finishButton);

    expect(finishButton, findsOneWidget);
    expect(find.text('Air habis'), findsNothing);
  });

  testWidgets('tenggat tahap terakhir otomatis membuka placeholder hasil', (
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

    time.seconds = 100;
    await tester.pump(sessionUiRefreshInterval);
    await tester.pumpAndSettle();

    expect(find.text('Hasil seduh'), findsWidgets);
    expect(find.textContaining('01:40'), findsOneWidget);
    expect(find.textContaining('Lewat'), findsNothing);
  });
}

Widget _screen(BrewPlan plan, {_FakeTimeSource? timeSource}) {
  return BrewSessionScreen(
    plan: plan,
    timeSource: timeSource ?? _FakeTimeSource(),
    shakeDetector: BrewShakeDetector(
      events: const Stream<AccelerometerEvent>.empty(),
    ),
    wakeLock: const _FakeWakeLock(),
    feedback: BrewStageFeedback(
      vibrate: (_) async {},
      cancelVibration: () async {},
      playTransitionSound: () async {},
      playCompletionSound: () async {},
      stopSound: () async {},
      delay: (_) async {},
    ),
  );
}

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

  @override
  Duration get elapsed => Duration(seconds: seconds);

  @override
  void reset() {
    seconds = 0;
  }

  @override
  void start() {}

  @override
  void stop() {}
}

class _FakeWakeLock implements BrewWakeLock {
  const _FakeWakeLock();

  @override
  Future<void> disable() async {}

  @override
  Future<void> enable() async {}
}
