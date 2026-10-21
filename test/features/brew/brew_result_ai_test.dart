import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/core/ui/app_button.dart';
import 'package:tetes/core/ui/app_chip.dart';
import 'package:tetes/data/remote/ai_client.dart';
import 'package:tetes/data/repositories/bean_repo.dart';
import 'package:tetes/data/repositories/brew_repo.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/features/auth/state/auth_providers.dart';
import 'package:tetes/features/auth/state/session_controller.dart';
import 'package:tetes/features/beans/bean_model.dart';
import 'package:tetes/features/beans/state/bean_providers.dart';
import 'package:tetes/features/brew/brew_calculator.dart';
import 'package:tetes/features/brew/brew_session_result.dart';
import 'package:tetes/features/brew/screens/brew_result_placeholder_screen.dart';
import 'package:tetes/features/brew/state/ai_client_provider.dart';
import 'package:tetes/features/brew/state/brew_setup_controller.dart';
import 'package:tetes/features/journal/journal_model.dart';

void main() {
  testWidgets('diagnosa baru tersedia setelah skor dan tag rasa dipilih', (
    tester,
  ) async {
    _useTallViewport(tester);
    final response = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(_app(response));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(AppButton, 'Minta Diagnosa AI');
    expect(tester.widget<AppButton>(button).onPressed, isNull);

    await tester.scrollUntilVisible(
      find.widgetWithText(AppChip, '3'),
      400,
      scrollable: _resultScrollable(),
    );
    await tester.tap(find.widgetWithText(AppChip, '3'));
    await tester.pump();
    expect(tester.widget<AppButton>(button).onPressed, isNull);

    await tester.scrollUntilVisible(
      find.widgetWithText(AppChip, 'Asam'),
      400,
      scrollable: _resultScrollable(),
    );
    await tester.tap(find.widgetWithText(AppChip, 'Asam'));
    await tester.pump();
    expect(tester.widget<AppButton>(button).onPressed, isNotNull);
  });

  testWidgets('diagnosa AI yang sah tampil dengan rencana berikutnya', (
    tester,
  ) async {
    _useTallViewport(tester);
    final response = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(_app(response));
    await tester.pumpAndSettle();
    await _requestDiagnosis(tester);

    response.complete(_diagnosis(fromTemperature: 92));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Diagnosa AI'),
      400,
      scrollable: _resultScrollable(),
    );
    expect(find.text('Diagnosa AI'), findsOneWidget);
    expect(
      find.textContaining('Seduhan mungkin kurang terekstraksi.'),
      findsOneWidget,
    );
    expect(find.text('Terapkan ke seduhan berikutnya'), findsOneWidget);
  });

  testWidgets('respons diagnosa setelah isian berubah diabaikan', (
    tester,
  ) async {
    _useTallViewport(tester);
    final response = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(_app(response));
    await tester.pumpAndSettle();
    await _requestDiagnosis(tester);

    await tester.enterText(find.byType(TextField).last, 'Catatan baru');
    response.complete(_diagnosis(fromTemperature: 92));
    await tester.pumpAndSettle();

    expect(find.text('Catatan baru'), findsOneWidget);
    expect(find.text('Diagnosa AI'), findsNothing);
    expect(find.text('Terapkan ke seduhan berikutnya'), findsNothing);
  });

  testWidgets('respons diagnosa setelah layar ditutup diabaikan', (
    tester,
  ) async {
    _useTallViewport(tester);
    final response = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(_app(response));
    await tester.pumpAndSettle();
    await _requestDiagnosis(tester);

    await tester.pumpWidget(const SizedBox());
    response.complete(_diagnosis(fromTemperature: 92));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('401 setelah isian berubah tetap mengakhiri sesi', (
    tester,
  ) async {
    _useTallViewport(tester);
    final response = Completer<Map<String, dynamic>>();
    final storage = _SessionStorage();
    await tester.pumpWidget(_app(response, storage: storage));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BrewResultPlaceholderScreen)),
    );
    await _requestDiagnosis(tester);

    await tester.enterText(find.byType(TextField).last, 'Catatan baru');
    response.completeError(
      const AiException(AiFailure.unauthorized, 'Sesi tidak sah.'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Catatan baru'), findsOneWidget);
    expect(
      container.read(sessionControllerProvider).requireValue.status,
      SessionStatus.unauthenticated,
    );
    expect(storage.session, isNull);
  });

  testWidgets('401 setelah layar ditutup tetap mengakhiri sesi', (
    tester,
  ) async {
    _useTallViewport(tester);
    final response = Completer<Map<String, dynamic>>();
    final storage = _SessionStorage();
    final showResult = ValueNotifier(true);
    addTearDown(showResult.dispose);
    await tester.pumpWidget(
      _app(response, storage: storage, showResult: showResult),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BrewResultPlaceholderScreen)),
    );
    await _requestDiagnosis(tester);

    showResult.value = false;
    await tester.pump();
    response.completeError(
      const AiException(AiFailure.unauthorized, 'Sesi tidak sah.'),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      container.read(sessionControllerProvider).requireValue.status,
      SessionStatus.unauthenticated,
    );
    expect(storage.session, isNull);
  });

  testWidgets('401 lama tidak mengakhiri sesi akun pengganti', (tester) async {
    _useTallViewport(tester);
    final response = Completer<Map<String, dynamic>>();
    final storage = _SessionStorage();
    await tester.pumpWidget(_app(response, storage: storage));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BrewResultPlaceholderScreen)),
    );
    await _requestDiagnosis(tester);

    storage.session = const StoredSession(
      token: 'token-user-2',
      userId: 'user-2',
      expiresAt: '2099-01-01T00:00:00Z',
    );
    container
        .read(sessionControllerProvider.notifier)
        .markAuthenticated('user-2');
    response.completeError(
      const AiException(AiFailure.unauthorized, 'Sesi tidak sah.'),
    );
    await tester.pumpAndSettle();

    final session = container.read(sessionControllerProvider).requireValue;
    expect(session.status, SessionStatus.authenticated);
    expect(session.userId, 'user-2');
    expect(storage.session?.userId, 'user-2');
  });

  testWidgets('saran AI yang tidak menjadi rencana lokal memakai fallback', (
    tester,
  ) async {
    _useTallViewport(tester);
    final response = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(_app(response));
    await tester.pumpAndSettle();
    await _requestDiagnosis(tester);

    response.complete(_diagnosis(fromTemperature: 90));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Saran sederhana'),
      400,
      scrollable: _resultScrollable(),
    );
    expect(find.text('Saran sederhana'), findsOneWidget);
    expect(
      find.textContaining(
        'Saran AI tidak dapat dipakai sebagai rencana seduh.',
      ),
      findsOneWidget,
    );
  });
}

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _requestDiagnosis(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.widgetWithText(AppChip, '3'),
    400,
    scrollable: _resultScrollable(),
  );
  await tester.tap(find.widgetWithText(AppChip, '3'));
  await tester.pump();
  await tester.scrollUntilVisible(
    find.widgetWithText(AppChip, 'Asam'),
    400,
    scrollable: _resultScrollable(),
  );
  await tester.tap(find.widgetWithText(AppChip, 'Asam'));
  await tester.pump();
  await tester.scrollUntilVisible(
    find.text('Minta Diagnosa AI'),
    400,
    scrollable: _resultScrollable(),
  );
  expect(
    tester
        .widget<AppButton>(find.widgetWithText(AppButton, 'Minta Diagnosa AI'))
        .onPressed,
    isNotNull,
  );
  await tester.tap(find.text('Minta Diagnosa AI'));
  await tester.pump();
}

Finder _resultScrollable() => find
    .descendant(
      of: find.byType(BrewResultPlaceholderScreen),
      matching: find.byType(Scrollable),
    )
    .first;

Widget _app(
  Completer<Map<String, dynamic>> response, {
  _SessionStorage? storage,
  ValueNotifier<bool>? showResult,
}) {
  final plan = BrewCalculator.createDefault(beanId: 'bean-1');
  final result = BrewResultPlaceholderScreen(
    result: BrewSessionResult(
      plan: plan,
      totalTimeS: plan.totalTimeSeconds,
      drawdownS: null,
      brewedAtUtc: '2026-10-21T00:00:00Z',
    ),
  );
  return ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(storage ?? _SessionStorage()),
      sessionControllerProvider.overrideWith(_SessionController.new),
      beanRepositoryProvider.overrideWith((ref) async => _BeanRepository()),
      brewRepositoryProvider.overrideWith((ref) async => _BrewRepository()),
      aiClientProvider.overrideWith((ref) => _AiClient(response.future)),
    ],
    child: MaterialApp(
      home: showResult == null
          ? result
          : ValueListenableBuilder<bool>(
              valueListenable: showResult,
              builder: (_, visible, _) => visible ? result : const SizedBox(),
            ),
    ),
  );
}

Map<String, dynamic> _diagnosis({required int fromTemperature}) => {
  'diagnosis': 'Seduhan mungkin kurang terekstraksi.',
  'likely_causes': ['Suhu air terlalu rendah.'],
  'suggestions': [
    {
      'variable': 'water_temp_c',
      'from': fromTemperature,
      'to': 93,
      'reason': 'Naikkan suhu sedikit.',
    },
  ],
  'note': 'Uji satu perubahan dulu.',
};

class _SessionController extends SessionController {
  @override
  Future<SessionState> build() async =>
      const SessionState.authenticated('user-1');
}

class _SessionStorage extends Fake implements SessionStorage {
  StoredSession? session = const StoredSession(
    token: 'token-user-1',
    userId: 'user-1',
    expiresAt: '2099-01-01T00:00:00Z',
  );

  @override
  Future<StoredSession?> readSession() async => session;

  @override
  Future<void> clearSession() async => session = null;
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
  Future<List<BrewDetailData>> findAiHistory({
    required String userId,
    required String beanId,
  }) async => const [];
}

class _AiClient extends Fake implements AiClient {
  _AiClient(this.response);
  final Future<Map<String, dynamic>> response;

  @override
  Future<Map<String, dynamic>> diagnose({
    required String userId,
    required Map<String, Object?> payload,
  }) => response;
}
