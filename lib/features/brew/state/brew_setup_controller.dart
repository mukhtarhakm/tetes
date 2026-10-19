import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/repositories/brew_repo.dart';
import '../../auth/state/session_controller.dart';
import '../../beans/bean_model.dart';
import '../../beans/state/bean_providers.dart';
import '../brew_calculator.dart';
import '../brew_plan.dart';

final brewRepositoryProvider = FutureProvider<BrewRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return BrewRepository(database);
});

final brewSetupControllerProvider = AsyncNotifierProvider.autoDispose
    .family<BrewSetupController, BrewSetupState, String?>(
      BrewSetupController.new,
    );

class BrewSetupState {
  const BrewSetupState({
    required this.beans,
    this.selectedBeanId,
    this.plan,
    this.isPlanLoading = false,
    this.fieldErrors = const {},
    this.notice,
  });

  final List<Bean> beans;
  final String? selectedBeanId;
  final BrewPlan? plan;
  final bool isPlanLoading;
  final Map<String, String> fieldErrors;
  final String? notice;

  bool get canStart =>
      selectedBeanId != null &&
      plan != null &&
      !isPlanLoading &&
      fieldErrors.isEmpty;

  BrewSetupState copyWith({
    List<Bean>? beans,
    Object? selectedBeanId = _unset,
    Object? plan = _unset,
    bool? isPlanLoading,
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
      fieldErrors: fieldErrors ?? this.fieldErrors,
      notice: identical(notice, _unset) ? this.notice : notice as String?,
    );
  }
}

class BrewSetupController extends AsyncNotifier<BrewSetupState> {
  BrewSetupController(this.initialBeanId);

  final String? initialBeanId;

  @override
  Future<BrewSetupState> build() async {
    final userId = await _activeUserId();
    final beanRepository = await ref.watch(beanRepositoryProvider.future);
    final beans = await beanRepository.listActive(userId);
    final initialBean = initialBeanId == null
        ? null
        : _findBean(beans, initialBeanId!);
    if (initialBean == null) {
      return BrewSetupState(beans: beans);
    }
    final plan = await _loadPlan(userId: userId, bean: initialBean);
    return BrewSetupState(
      beans: beans,
      selectedBeanId: initialBean.id,
      plan: plan,
    );
  }

  Future<void> selectBean(String? beanId) async {
    final current = _current;
    if (beanId == null) {
      state = AsyncData(
        current.copyWith(
          selectedBeanId: null,
          plan: null,
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
      _setFieldError('dose', error);
      return;
    }
    final current = _current;
    final plan = current.plan;
    if (plan == null) {
      return;
    }
    _applyPlanChange(
      fieldKey: 'dose',
      change: () => BrewCalculator.updateParameters(plan, doseG: value),
      clearStageErrors: value != plan.doseG,
      notice: value == plan.doseG
          ? null
          : 'Tahap dibuat ulang dari nilai bawaan.',
    );
  }

  void updateRatio(String input) {
    final value = _parseDouble(input);
    final error = BrewValidation.ratio(value);
    if (error != null) {
      _setFieldError('ratio', error);
      return;
    }
    final current = _current;
    final plan = current.plan;
    if (plan == null) {
      return;
    }
    _applyPlanChange(
      fieldKey: 'ratio',
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
      _setFieldError('temperature', error);
      return;
    }
    final plan = _current.plan;
    if (plan == null) {
      return;
    }
    _applyPlanChange(
      fieldKey: 'temperature',
      change: () => BrewCalculator.updateParameters(plan, waterTempC: value),
    );
  }

  void updateGrind(Grind grind) {
    final plan = _current.plan;
    if (plan == null) {
      return;
    }
    _applyPlanChange(
      change: () => BrewCalculator.updateParameters(plan, grind: grind),
    );
  }

  void updatePouringCount(int count) {
    final error = BrewValidation.pouringCount(count);
    if (error != null) {
      _setFieldError('pouring', error);
      return;
    }
    final plan = _current.plan;
    if (plan == null) {
      return;
    }
    _applyPlanChange(
      fieldKey: 'pouring',
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
        current.copyWith(plan: nextPlan, fieldErrors: errors, notice: notice),
      );
    } on BrewPlanException catch (error) {
      if (fieldKey != null) {
        _setFieldError(fieldKey, error.message);
      }
    }
  }

  void _setFieldError(String key, String message) {
    final current = _current;
    state = AsyncData(
      current.copyWith(
        fieldErrors: {...current.fieldErrors, key: message},
        notice: null,
      ),
    );
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
