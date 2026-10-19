import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/brew_plan.dart';
import 'package:tetes/features/brew/screens/brew_session_screen.dart';
import 'package:tetes/features/brew/services/brew_session_hardware.dart';
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
}

Widget _screen(BrewPlan plan) {
  return BrewSessionScreen(
    plan: plan,
    timeSource: _FakeTimeSource(),
    shakeDetector: BrewShakeDetector(
      events: const Stream<AccelerometerEvent>.empty(),
    ),
    wakeLock: const _FakeWakeLock(),
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
  @override
  Duration get elapsed => Duration.zero;

  @override
  void reset() {}

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
