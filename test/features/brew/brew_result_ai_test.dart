import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/data/repositories/bean_repo.dart';
import 'package:tetes/data/repositories/brew_repo.dart';
import 'package:tetes/features/auth/state/session_controller.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/beans/state/bean_providers.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/brew_session_result.dart';
import 'package:tetes/core/ui/app_chip.dart';
import 'package:tetes/features/brew/screens/brew_result_screen.dart';
import 'package:tetes/features/brew/state/brew_setup_controller.dart';
import 'package:tetes/features/journal/screens/brew_detail_screen.dart';
import 'package:tetes/features/journal/state/journal_controller.dart';

void main() {
  testWidgets('Hasil hanya memberi tahu diagnosa tersedia setelah simpan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plan = BrewCalculator.createDefault(beanId: 'bean-1');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_SessionController.new),
          beanRepositoryProvider.overrideWith((ref) async => _BeanRepository()),
          brewRepositoryProvider.overrideWith((ref) async => _BrewRepository()),
          brewDetailProvider('brew-new').overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: BrewResultScreen(
            result: BrewSessionResult(
              plan: plan,
              totalTimeS: 135,
              drawdownS: null,
              brewedAtUtc: '2026-10-21T00:00:00Z',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Diagnosa AI tersedia setelah menyimpan'), findsOneWidget);
    expect(find.text('Minta Diagnosa AI'), findsNothing);
    expect(find.byType(BrewDetailScreen), findsNothing);
  });

  testWidgets('Hasil tidak overflow pada lebar 320 dan teks 1,3x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plan = BrewCalculator.createDefault(beanId: 'bean-1');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_SessionController.new),
          beanRepositoryProvider.overrideWith((ref) async => _BeanRepository()),
          brewRepositoryProvider.overrideWith((ref) async => _BrewRepository()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: BrewResultScreen(
            result: BrewSessionResult(
              plan: plan,
              totalTimeS: 135,
              drawdownS: null,
              brewedAtUtc: '2026-10-21T00:00:00Z',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Simpan membuka Detail dan Back kembali ke layar akar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plan = BrewCalculator.createDefault(beanId: 'bean-1');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionControllerProvider.overrideWith(_SessionController.new),
          beanRepositoryProvider.overrideWith((ref) async => _BeanRepository()),
          brewRepositoryProvider.overrideWith((ref) async => _BrewRepository()),
          brewDetailProvider('brew-new').overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BrewResultScreen(
                      result: BrewSessionResult(
                        plan: plan,
                        totalTimeS: 135,
                        drawdownS: null,
                        brewedAtUtc: '2026-10-21T00:00:00Z',
                      ),
                    ),
                  ),
                ),
                child: const Text('Buka hasil'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka hasil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.widgetWithText(AppChip, 'Asam'));
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.tap(find.text('Simpan').last);
    await tester.pumpAndSettle();
    expect(find.byType(BrewDetailScreen), findsOneWidget);
    expect(find.text('Seduhan tersimpan'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Buka hasil'), findsOneWidget);
  });
}

class _SessionController extends SessionController {
  @override
  Future<SessionState> build() async =>
      const SessionState.authenticated('user-1');
}

class _BeanRepository extends Fake implements BeanRepository {
  @override
  Future<Bean?> findById({required String userId, required String id}) async =>
      const Bean(
        id: 'bean-1',
        userId: 'user-1',
        name: 'Biji Uji',
        species: BeanSpecies.arabika,
        isSelfRoasted: false,
        initialStockG: 250,
        remainingStockG: 250,
        roasteryNotesTags: [],
        archived: false,
        createdAt: '2026-10-21T00:00:00Z',
        updatedAt: '2026-10-21T00:00:00Z',
        syncStatus: 'pending',
        brewCount: 0,
      );
}

class _BrewRepository extends Fake implements BrewRepository {
  @override
  Future<double> remainingStockG({
    required String userId,
    required String beanId,
  }) async => 250;
  @override
  Future<String> save({
    required String userId,
    required BrewSessionResult result,
    required int tasteScore,
    required Iterable<RoasteryNoteTag> tasteTags,
    required List<double?> actualWaterG,
    int? drawdownS,
    String? notes,
  }) async {
    return 'brew-new';
  }
}
