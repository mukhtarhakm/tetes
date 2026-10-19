import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/screens/brew_setup_screen.dart';
import 'package:tetes/features/brew/state/brew_setup_controller.dart';

void main() {
  testWidgets('menampilkan keadaan memuat', (tester) async {
    final pending = Completer<BrewSetupState>();
    await tester.pumpWidget(_app(() => pending.future));
    await tester.pump();

    expect(find.text('Memuat pengaturan seduh...'), findsOneWidget);
  });

  testWidgets('menampilkan keadaan galat dengan aksi coba lagi', (
    tester,
  ) async {
    await tester.pumpWidget(_app(() => Future.error(StateError('uji'))));
    await tester.pumpAndSettle();

    expect(find.text('Pengaturan seduh tidak dapat dimuat.'), findsOneWidget);
    expect(find.text('Coba lagi'), findsOneWidget);
  });

  testWidgets('tanpa biji aktif mengarahkan ke tambah biji', (tester) async {
    await tester.pumpWidget(_app(() async => const BrewSetupState(beans: [])));
    await tester.pumpAndSettle();

    expect(find.text('Belum ada biji aktif'), findsOneWidget);
    expect(find.text('Tambah biji'), findsOneWidget);
  });

  testWidgets('keadaan berhasil menampilkan form dan visual rencana', (
    tester,
  ) async {
    final bean = _bean();
    final plan = BrewCalculator.createDefault(beanId: bean.id);
    await tester.pumpWidget(
      _app(
        () async =>
            BrewSetupState(beans: [bean], selectedBeanId: bean.id, plan: plan),
        initialBeanId: bean.id,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total air'), findsOneWidget);
    expect(find.text('240 g'), findsWidgets);
    expect(find.text('Timeline'), findsOneWidget);
    expect(find.text('Air kumulatif terhadap waktu'), findsOneWidget);
    expect(find.text('Rekomendasikan dengan AI'), findsOneWidget);
    expect(find.text('Mulai Sesi'), findsOneWidget);
  });
}

Widget _app(Future<BrewSetupState> Function() load, {String? initialBeanId}) {
  return ProviderScope(
    overrides: [
      brewSetupControllerProvider.overrideWith2(
        (argument) => _FakeBrewSetupController(argument, load),
      ),
    ],
    child: MaterialApp(home: BrewSetupScreen(initialBeanId: initialBeanId)),
  );
}

class _FakeBrewSetupController extends BrewSetupController {
  _FakeBrewSetupController(super.initialBeanId, this.load);

  final Future<BrewSetupState> Function() load;

  @override
  Future<BrewSetupState> build() => load();
}

Bean _bean() {
  return const Bean(
    id: 'bean-1',
    userId: 'user-1',
    name: 'Biji Uji',
    species: BeanSpecies.arabika,
    isSelfRoasted: false,
    initialStockG: 250,
    remainingStockG: 250,
    roasteryNotesTags: [],
    archived: false,
    createdAt: '2026-10-19T00:00:00Z',
    updatedAt: '2026-10-19T00:00:00Z',
    syncStatus: 'pending',
    brewCount: 0,
  );
}
