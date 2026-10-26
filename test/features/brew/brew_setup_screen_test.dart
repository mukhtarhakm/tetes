import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/app/theme/tokens.dart';
import 'package:tetes/core/ui/app_card.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/brew/ai_brew.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/screens/brew_setup_screen.dart';
import 'package:tetes/features/brew/state/brew_setup_controller.dart';
import 'package:tetes/features/brew/widgets/brew_stage_colors.dart';

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
    expect(find.textContaining('Jeda'), findsNothing);
    expect(find.text('Rekomendasikan dengan AI'), findsOneWidget);
    expect(find.text('Mulai Sesi'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AppCard && widget.backgroundColor == AppColors.stage1,
      ),
      findsOneWidget,
    );
  });

  testWidgets('kartu AI menampilkan perubahan pouring dan sorotan label', (
    tester,
  ) async {
    final bean = _bean();
    final before = BrewCalculator.createDefault(beanId: bean.id);
    final recommended = BrewCalculator.createDefault(
      beanId: bean.id,
      pouringCount: 2,
    );
    await tester.pumpWidget(
      _app(
        () async => BrewSetupState(
          beans: [bean],
          selectedBeanId: bean.id,
          plan: recommended,
          aiSuggestion: AppliedAiSuggestion(
            before: before,
            recommended: recommended,
            note: 'Profil biji cocok untuk dua tuangan.',
            hasHistory: false,
          ),
        ),
        initialBeanId: bean.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pouring: 3 ke 2'), findsOneWidget);
    expect(find.text('Jumlah pouring'), findsOneWidget);
    expect(find.text('Kembalikan'), findsOneWidget);
  });

  testWidgets('dosis melebihi stok menampilkan pesan dan menonaktifkan mulai', (
    tester,
  ) async {
    final bean = _bean(remainingStockG: 10);
    final plan = BrewCalculator.createDefault(beanId: bean.id);
    await tester.pumpWidget(
      _app(
        () async =>
            BrewSetupState(beans: [bean], selectedBeanId: bean.id, plan: plan),
        initialBeanId: bean.id,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Biji Biji Uji tinggal 10 g. Dosis 15 g melebihi stok.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('insufficient-stock-warning')), findsOneWidget);
    expect(
      BrewSetupState(
        beans: [bean],
        selectedBeanId: bean.id,
        plan: plan,
      ).canStart,
      isFalse,
    );
    final equalPlan = BrewCalculator.updateParameters(plan, doseG: 10);
    expect(
      BrewSetupState(
        beans: [bean],
        selectedBeanId: bean.id,
        plan: equalPlan,
      ).canStart,
      isTrue,
    );
  });

  testWidgets('Atur Seduh tidak overflow pada lebar 320 dan teks 1,3x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bean = _bean();
    final plan = BrewCalculator.createDefault(beanId: bean.id);
    await tester.pumpWidget(
      _app(
        () async =>
            BrewSetupState(beans: [bean], selectedBeanId: bean.id, plan: plan),
        initialBeanId: bean.id,
        textScale: 1.3,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 8; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  test('pemetaan warna tahap memakai lima token tema', () {
    expect(BrewStageColors.forPosition(1), AppColors.stage1);
    expect(BrewStageColors.forPosition(2), AppColors.stage2);
    expect(BrewStageColors.forPosition(3), AppColors.stage3);
    expect(BrewStageColors.forPosition(4), AppColors.stage4);
    expect(BrewStageColors.forPosition(5), AppColors.stage5);
  });
}

Widget _app(
  Future<BrewSetupState> Function() load, {
  String? initialBeanId,
  double textScale = 1,
}) {
  return ProviderScope(
    overrides: [
      brewSetupControllerProvider.overrideWith2(
        (argument) => _FakeBrewSetupController(argument, load),
      ),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: BrewSetupScreen(initialBeanId: initialBeanId),
    ),
  );
}

class _FakeBrewSetupController extends BrewSetupController {
  _FakeBrewSetupController(super.initialBeanId, this.load);

  final Future<BrewSetupState> Function() load;

  @override
  Future<BrewSetupState> build() => load();
}

Bean _bean({double remainingStockG = 250}) {
  return Bean(
    id: 'bean-1',
    userId: 'user-1',
    name: 'Biji Uji',
    species: BeanSpecies.arabika,
    isSelfRoasted: false,
    initialStockG: 250,
    remainingStockG: remainingStockG,
    roasteryNotesTags: [],
    archived: false,
    createdAt: '2026-10-19T00:00:00Z',
    updatedAt: '2026-10-19T00:00:00Z',
    syncStatus: 'pending',
    brewCount: 0,
  );
}
