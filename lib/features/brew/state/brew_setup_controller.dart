import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/remote/ai_client.dart';
import '../../../data/repositories/brew_repo.dart';
import '../../../data/secure/session_storage.dart';
import '../../auth/session/force_logout.dart';
import '../../auth/state/auth_providers.dart';
import '../../auth/state/session_controller.dart';
import '../../beans/bean_model.dart';
import '../../beans/state/bean_providers.dart';
import '../ai_brew.dart';
import '../brew_calculator.dart';
import '../brew_plan.dart';
import 'ai_client_provider.dart';

final brewRepositoryProvider = FutureProvider<BrewRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return BrewRepository(database);
});

// Rencana awal dari Seduh lagi atau Terapkan diagnosa. Di-override per layar
// lewat ProviderScope, jadi controller wajib mendaftarkannya di dependencies;
// tanpa itu controller membaca nilai root (null) dan memuat pengaturan terbaik.
final initialBrewPlanProvider = Provider<BrewPlan?>(
  (ref) => null,
  dependencies: const [],
);

class AiRequestCooldown {
  Timer? _timer;
  DateTime? _until;

  bool get active => _until != null && DateTime.now().isBefore(_until!);

  void start(void Function(int seconds) onTick) {
    _timer?.cancel();
    _until = DateTime.now().add(const Duration(seconds: 30));
    onTick(30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = _until!.difference(DateTime.now());
      final seconds = remaining.isNegative
          ? 0
          : (remaining.inMilliseconds / 1000).ceil();
      onTick(seconds);
      if (seconds == 0) {
        _until = null;
        timer.cancel();
      }
    });
  }

  void dispose() => _timer?.cancel();
}

final brewSetupControllerProvider = AsyncNotifierProvider.autoDispose
    .family<BrewSetupController, BrewSetupState, String?>(
      BrewSetupController.new,
      dependencies: [initialBrewPlanProvider],
    );

class BrewSetupState {
  const BrewSetupState({
    required this.beans,
    this.selectedBeanId,
    this.plan,
    this.isPlanLoading = false,
    this.isAiLoading = false,
    this.aiCooldownSeconds = 0,
    this.aiSuggestion,
    this.fieldErrors = const {},
    this.notice,
  });

  final List<Bean> beans;
  final String? selectedBeanId;
  final BrewPlan? plan;
  final bool isPlanLoading;
  final bool isAiLoading;
  final int aiCooldownSeconds;
  final AppliedAiSuggestion? aiSuggestion;
  final Map<String, String> fieldErrors;
  final String? notice;

  String? get stockWarning {
    final selected = beans
        .where((bean) => bean.id == selectedBeanId)
        .firstOrNull;
    if (selected == null ||
        plan == null ||
        plan!.doseG <= selected.remainingStockG) {
      return null;
    }
    return InsufficientStockException(
      selected.name,
      selected.remainingStockG,
      plan!.doseG,
    ).message;
  }

  bool get canStart =>
      selectedBeanId != null &&
      plan != null &&
      !isPlanLoading &&
      !isAiLoading &&
      fieldErrors.isEmpty &&
      stockWarning == null;

  BrewSetupState copyWith({
    List<Bean>? beans,
    Object? selectedBeanId = _unset,
    Object? plan = _unset,
    bool? isPlanLoading,
    bool? isAiLoading,
    int? aiCooldownSeconds,
    Object? aiSuggestion = _unset,
    Map<String, String>? fieldErrors,
    Object? notice = _unset,
  }) {
    return BrewSetupState(
      beans: beans ?? this.beans,
      selectedBeanId: identical(selectedBeanId, _unset)
          ? this.selectedBeanId
          : selectedBeanId as String?,
      plan: identical(plan, _unset) ? this.plan : plan as BrewPlan?,
      isPlanLoading: isPlanLoading ?? this.isPlanLoading,
      isAiLoading: isAiLoading ?? this.isAiLoading,
      aiCooldownSeconds: aiCooldownSeconds ?? this.aiCooldownSeconds,
      aiSuggestion: identical(aiSuggestion, _unset)
          ? this.aiSuggestion
          : aiSuggestion as AppliedAiSuggestion?,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      notice: identical(notice, _unset) ? this.notice : notice as String?,
    );
  }
}

class BrewSetupController extends AsyncNotifier<BrewSetupState> {
  BrewSetupController(this.initialBeanId);

  final String? initialBeanId;
  int _revision = 0;
  bool _disposed = false;
  final _aiCooldown = AiRequestCooldown();

  @override
  Future<BrewSetupState> build() async {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _aiCooldown.dispose();
    });
    final userId = await _activeUserId();
    final beanRepository = await ref.watch(beanRepositoryProvider.future);
    final beans = await beanRepository.listActive(userId);
    final initialBean = initialBeanId == null
        ? null
        : _findBean(beans, initialBeanId!);
    if (initialBean == null) {
      return BrewSetupState(beans: beans);
    }
    final customPlan = ref.watch(initialBrewPlanProvider);
    final plan = (customPlan != null && customPlan.beanId == initialBean.id)
        ? customPlan
        : await _loadPlan(userId: userId, bean: initialBean);
    return BrewSetupState(
      beans: beans,
      selectedBeanId: initialBean.id,
      plan: plan,
    );
  }

  Future<void> selectBean(String? beanId) async {
    _revision++;
    final current = _current;
    if (beanId == null) {
      state = AsyncData(
        current.copyWith(
          selectedBeanId: null,
          plan: null,
          isAiLoading: false,
          aiSuggestion: null,
          fieldErrors: const {},
          notice: null,
        ),
      );
      return;
    }
    final bean = _findBean(current.beans, beanId);
    if (bean == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(
        selectedBeanId: beanId,
        plan: null,
        isPlanLoading: true,
        isAiLoading: false,
        aiSuggestion: null,
        fieldErrors: const {},
        notice: null,
      ),
    );
    try {
      final userId = await _activeUserId();
      final plan = await _loadPlan(userId: userId, bean: bean);
      final latest = _current;
      if (latest.selectedBeanId == beanId) {
        state = AsyncData(latest.copyWith(plan: plan, isPlanLoading: false));
      }
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  void updateDose(String input) {
    final value = _parseDouble(input);
    final error = BrewValidation.dose(value);
    if (error != null) {
      _setFieldError('dose', error, aiField: AiPlanField.dose);
      return;
    }
    final current = _current;
    final plan = current.plan;
    if (plan == null) {
      return;
    }
    _applyPlanChange(
      fieldKey: 'dose',
      aiField: AiPlanField.dose,
      change: () => BrewCalculator.updateParameters(plan, doseG: value),
      clearStageErrors: value != plan.doseG,
      notice: value == plan.doseG
          ? null
          : 'Tahap dibuat ulang dari nilai bawaan.',
    );
  }

  Future<void> recommend({
    required bool Function() isScreenCurrent,
    AiRecommendPreferences? preferences,
  }) async {
    final prefs = preferences == null || preferences.isEmpty
        ? null
        : preferences;
    final current = _current;
    final bean = current.beans
        .where((item) => item.id == current.selectedBeanId)
        .firstOrNull;
    final plan = current.plan;
    if (bean == null ||
        plan == null ||
        current.isAiLoading ||
        _aiCooldown.active) {
      return;
    }

    final requestRevision = ++_revision;
    state = AsyncData(current.copyWith(isAiLoading: true, notice: null));
    var fallback = BrewCalculator.createDefault(beanId: bean.id);
    final sessionStorage = ref.read(sessionStorageProvider);
    final sessionController = ref.read(sessionControllerProvider.notifier);
    String? requestUserId;

    bool isLatest() => !_disposed && requestRevision == _revision;
    void finish({
      required BrewPlan nextPlan,
      String? notice,
      AppliedAiSuggestion? aiSuggestion,
    }) {
      if (!isLatest()) return;
      final latest = _current;
      state = AsyncData(
        latest.copyWith(
          plan: nextPlan,
          isAiLoading: false,
          fieldErrors: const {},
          notice: notice,
          aiSuggestion: aiSuggestion,
        ),
      );
    }

    void finishIfScreenLeft() {
      if (!isLatest() || isScreenCurrent()) return;
      state = AsyncData(_current.copyWith(isAiLoading: false));
    }

    try {
      final session = await ref.read(sessionControllerProvider.future);
      if (!isLatest() || !isScreenCurrent()) {
        finishIfScreenLeft();
        return;
      }
      if (session.status != SessionStatus.authenticated ||
          session.userId == null) {
        await forceLogoutOnUnauthorized(sessionController);
        return;
      }
      final userId = session.userId!;
      requestUserId = userId;
      final repository = await ref.read(brewRepositoryProvider.future);
      fallback = await _loadPlan(userId: userId, bean: bean);
      final history = await repository.findAiHistory(
        userId: userId,
        beanId: bean.id,
      );
      if (!isLatest() || !isScreenCurrent()) {
        finishIfScreenLeft();
        return;
      }
      final response = await ref
          .read(aiClientProvider)
          .recommend(
            userId: userId,
            payload: AiBrew.recommendPayload(
              bean: bean,
              history: history,
              pouringCount: plan.pouringCount,
              preferences: prefs,
            ),
          );
      if (!isLatest() || !isScreenCurrent()) {
        finishIfScreenLeft();
        return;
      }
      final recommendation = AiBrew.recommendationFromResponse(
        fallback: fallback,
        response: response,
        preferences: prefs,
      );
      finish(
        nextPlan: recommendation.plan,
        notice: recommendation.usedFallback
            ? 'Saran AI tidak dapat dipakai. Pengaturan sederhana digunakan (bukan AI).'
            : null,
        aiSuggestion: recommendation.usedFallback
            ? null
            : AppliedAiSuggestion(
                before: plan,
                recommended: recommendation.plan,
                note: recommendation.note,
                hasHistory: history.isNotEmpty,
                preferences: prefs,
              ),
      );
    } on AiException catch (error) {
      if (error.failure == AiFailure.unauthorized) {
        try {
          final storedSession = await sessionStorage.readSession();
          if (requestUserId != null && storedSession?.userId == requestUserId) {
            await forceLogoutOnUnauthorized(sessionController);
          }
        } on SessionStorageException {
          // Akun aktif tidak dapat dipastikan, jadi jangan hapus sesinya.
        }
        finishIfScreenLeft();
        return;
      }
      if (error.failure == AiFailure.network ||
          error.failure == AiFailure.rateLimited ||
          error.failure == AiFailure.invalidOutput ||
          error.failure == AiFailure.upstream ||
          error.failure == AiFailure.timeout) {
        _startAiCooldown();
      }
      if (!isLatest() || !isScreenCurrent()) {
        finishIfScreenLeft();
        return;
      }
      final message = error.upstreamStatus == 503 || error.upstreamStatus == 429
          ? 'Layanan AI sedang sibuk, coba lagi sebentar.'
          : error.message;
      finish(
        nextPlan: fallback,
        notice:
            '${AiBrew.fallbackRecommendation(fallback, reason: message).note} Aturan sederhana, bukan AI.',
      );
    } catch (_) {
      if (!isLatest() || !isScreenCurrent()) {
        finishIfScreenLeft();
        return;
      }
      finish(
        nextPlan: fallback,
        notice:
            'Saran AI tidak tersedia. Pengaturan sederhana digunakan (bukan AI).',
      );
    }
  }

  void updateRatio(String input) {
    final value = _parseDouble(input);
    final error = BrewValidation.ratio(value);
    if (error != null) {
      _setFieldError('ratio', error, aiField: AiPlanField.ratio);
      return;
    }
    final current = _current;
    final plan = current.plan;
    if (plan == null) {
      return;
    }
    _applyPlanChange(
      fieldKey: 'ratio',
      aiField: AiPlanField.ratio,
      change: () => BrewCalculator.updateParameters(plan, ratio: value),
      clearStageErrors: value != plan.ratio,
      notice: value == plan.ratio
          ? null
          : 'Tahap dibuat ulang dari nilai bawaan.',
    );
  }

  void updateTemperature(String input) {
    final value = int.tryParse(input.trim());
    final error = BrewValidation.temperature(value);
    if (error != null) {
      _setFieldError('temperature', error, aiField: AiPlanField.temperature);
      return;
    }
    final plan = _current.plan;
    if (plan == null) {
      return;
    }
    _applyPlanChange(
      fieldKey: 'temperature',
      aiField: AiPlanField.temperature,
      change: () => BrewCalculator.updateParameters(plan, waterTempC: value),
    );
  }

  void updateGrind(Grind grind) {
    final plan = _current.plan;
    if (plan == null) {
      return;
    }
    _applyPlanChange(
      aiField: AiPlanField.grind,
      change: () => BrewCalculator.updateParameters(plan, grind: grind),
    );
  }

  void updatePouringCount(int count) {
    final error = BrewValidation.pouringCount(count);
    if (error != null) {
      _setFieldError('pouring', error, aiField: AiPlanField.pouring);
      return;
    }
    final plan = _current.plan;
    if (plan == null) {
      return;
    }
    _applyPlanChange(
      fieldKey: 'pouring',
      aiField: AiPlanField.pouring,
      change: () => BrewCalculator.updateParameters(plan, pouringCount: count),
      clearStageErrors: count != plan.pouringCount,
      notice: count == plan.pouringCount
          ? null
          : 'Tahap dibuat ulang dari nilai bawaan.',
    );
  }

  void updateStageDuration(int stageIndex, String input) {
    final value = int.tryParse(input.trim());
    final key = 'duration_$stageIndex';
    final error = BrewValidation.duration(value);
    if (error != null) {
      _setFieldError(key, error);
      return;
    }
    final plan = _current.plan;
    if (plan == null) {
      return;
    }
    _applyPlanChange(
      fieldKey: key,
      change: () => BrewCalculator.updateDuration(
        plan,
        stageIndex: stageIndex,
        durationSeconds: value!,
      ),
    );
  }

  void updateStageTarget(int stageIndex, String input) {
    final value = _parseDouble(input);
    final key = 'target_$stageIndex';
    if (value == null || !value.isFinite || value <= 0) {
      _setFieldError(key, 'Target air harus lebih dari 0 gram.');
      return;
    }
    final plan = _current.plan;
    if (plan == null) {
      return;
    }
    _applyPlanChange(
      fieldKey: key,
      change: () => BrewCalculator.updateTargetPour(
        plan,
        stageIndex: stageIndex,
        targetPourG: value,
      ),
    );
  }

  BrewSetupState get _current => state.asData!.value;

  Future<String> _activeUserId() async {
    final session = await ref.watch(sessionControllerProvider.future);
    final userId = session.userId;
    if (session.status != SessionStatus.authenticated || userId == null) {
      throw StateError('Session pengguna tidak tersedia.');
    }
    return userId;
  }

  Future<BrewPlan> _loadPlan({
    required String userId,
    required Bean bean,
  }) async {
    final bestBrewId = bean.bestBrewId;
    if (bestBrewId != null) {
      final repository = await ref.read(brewRepositoryProvider.future);
      final bestPlan = await repository.findBestPlan(
        userId: userId,
        beanId: bean.id,
        bestBrewId: bestBrewId,
      );
      if (bestPlan != null) {
        return bestPlan;
      }
    }
    return BrewCalculator.createDefault(beanId: bean.id);
  }

  void _applyPlanChange({
    required BrewPlan Function() change,
    String? fieldKey,
    AiPlanField? aiField,
    String? notice,
    bool clearStageErrors = false,
  }) {
    final current = _current;
    try {
      final nextPlan = change();
      final errors = Map<String, String>.of(current.fieldErrors);
      if (fieldKey != null) {
        errors.remove(fieldKey);
      }
      if (clearStageErrors) {
        errors.removeWhere(
          (key, _) => key.startsWith('duration_') || key.startsWith('target_'),
        );
      }
      state = AsyncData(
        current.copyWith(
          plan: nextPlan,
          isAiLoading: false,
          fieldErrors: errors,
          notice: notice,
          aiSuggestion: aiField == null
              ? current.aiSuggestion
              : current.aiSuggestion?.markEdited(aiField),
        ),
      );
      _revision++;
    } on BrewPlanException catch (error) {
      if (fieldKey != null) {
        _setFieldError(fieldKey, error.message, aiField: aiField);
      }
    }
  }

  void _setFieldError(String key, String message, {AiPlanField? aiField}) {
    _revision++;
    final current = _current;
    state = AsyncData(
      current.copyWith(
        isAiLoading: false,
        fieldErrors: {...current.fieldErrors, key: message},
        notice: null,
        aiSuggestion: aiField == null
            ? current.aiSuggestion
            : current.aiSuggestion?.markEdited(aiField),
      ),
    );
  }

  void restoreBeforeAi() {
    final current = _current;
    final suggestion = current.aiSuggestion;
    if (suggestion == null) return;
    _revision++;
    state = AsyncData(
      current.copyWith(
        plan: suggestion.restore(),
        aiSuggestion: null,
        fieldErrors: const {},
        notice: null,
      ),
    );
  }

  void dismissAiSuggestion() {
    final current = _current;
    if (current.aiSuggestion == null) return;
    state = AsyncData(current.copyWith(aiSuggestion: null));
  }

  void _startAiCooldown() {
    if (_disposed) return;
    _aiCooldown.start((seconds) {
      if (_disposed) return;
      if (seconds != _current.aiCooldownSeconds) {
        state = AsyncData(_current.copyWith(aiCooldownSeconds: seconds));
      }
    });
  }
}

Bean? _findBean(List<Bean> beans, String id) {
  for (final bean in beans) {
    if (bean.id == id) {
      return bean;
    }
  }
  return null;
}

double? _parseDouble(String value) {
  return double.tryParse(value.trim().replaceAll(',', '.'));
}

const _unset = Object();
