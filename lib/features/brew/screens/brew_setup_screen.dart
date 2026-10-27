import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_dropdown_field.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/utils/display_format.dart';
import '../../beans/bean_model.dart';
import '../../beans/screens/bean_form_screen.dart';
import '../ai_brew.dart';
import '../brew_plan.dart';
import '../state/brew_setup_controller.dart';
import '../widgets/brew_stage_colors.dart';
import '../widgets/brew_timeline.dart';
import '../widgets/brew_water_chart.dart';
import 'brew_session_screen.dart';

class BrewSetupScreen extends ConsumerWidget {
  const BrewSetupScreen({this.initialBeanId, this.initialPlan, super.key});

  final String? initialBeanId;
  final BrewPlan? initialPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialPlan != null) {
      return ProviderScope(
        overrides: [initialBrewPlanProvider.overrideWithValue(initialPlan)],
        child: BrewSetupScreen(initialBeanId: initialPlan!.beanId),
      );
    }

    final provider = brewSetupControllerProvider(initialBeanId);
    final setup = ref.watch(provider);

    return Scaffold(
      appBar: AppBar(title: const Text('Atur Seduh')),
      body: SafeArea(
        top: false,
        child: setup.when(
          loading: () =>
              const LoadingView(message: 'Memuat pengaturan seduh...'),
          error: (_, _) => Padding(
            padding: AppInsets.screen,
            child: ErrorView(
              message: 'Pengaturan seduh tidak dapat dimuat.',
              onRetry: () => ref.invalidate(provider),
            ),
          ),
          data: (data) => data.beans.isEmpty
              ? Padding(
                  padding: AppInsets.screen,
                  child: EmptyView(
                    title: 'Belum ada biji aktif',
                    message:
                        'Tambahkan biji terlebih dahulu sebelum mengatur seduhan.',
                    icon: Icons.coffee_outlined,
                    actionLabel: 'Tambah biji',
                    onActionPressed: () => _openBeanForm(context, ref),
                  ),
                )
              : _BrewSetupContent(initialBeanId: initialBeanId, state: data),
        ),
      ),
    );
  }

  Future<void> _openBeanForm(BuildContext context, WidgetRef ref) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const BeanFormScreen()));
    if (saved == true) {
      ref.invalidate(brewSetupControllerProvider(initialBeanId));
    }
  }
}

class _BrewSetupContent extends ConsumerWidget {
  const _BrewSetupContent({required this.initialBeanId, required this.state});

  final String? initialBeanId;
  final BrewSetupState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(
      brewSetupControllerProvider(initialBeanId).notifier,
    );
    final selectedBean = _findBean(state.beans, state.selectedBeanId);
    final plan = state.plan;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s20,
              AppSpacing.s16,
              AppSpacing.s20,
              AppSpacing.s16,
            ),
            children: [
              AppDropdownField<Bean>(
                label: 'Biji kopi',
                items: state.beans,
                itemLabel: (bean) => bean.name,
                value: selectedBean,
                hintText: 'Pilih biji aktif',
                onChanged: (bean) => controller.selectBean(bean?.id),
              ),
              const SizedBox(height: AppSpacing.s16),
              if (state.isPlanLoading)
                const SizedBox(
                  height: AppSizes.statePreviewHeight,
                  child: LoadingView(message: 'Memuat rencana seduh...'),
                )
              else if (plan == null)
                const SizedBox(
                  height: AppSizes.statePreviewHeight,
                  child: EmptyView(
                    title: 'Pilih biji',
                    message: 'Pilih biji aktif untuk membuat rencana seduh.',
                    icon: Icons.touch_app_outlined,
                  ),
                )
              else
                _BrewForm(
                  state: state,
                  controller: controller,
                  selectedBean: selectedBean,
                  onRecommend: () async {
                    await controller.recommend(
                      isScreenCurrent: () =>
                          context.mounted &&
                          ModalRoute.of(context)?.isCurrent == true,
                    );
                  },
                ),
            ],
          ),
        ),
        if (plan != null && !state.isPlanLoading)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s20,
              AppSpacing.s12,
              AppSpacing.s20,
              AppSpacing.s16,
            ),
            decoration: const BoxDecoration(
              color: AppColors.background,
              boxShadow: AppShadows.card,
            ),
            child: AppButton(
              label: 'Mulai Sesi',
              icon: Icons.play_arrow_rounded,
              onPressed: state.canStart
                  ? () {
                      controller.dismissAiSuggestion();
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => BrewSessionScreen(plan: plan),
                        ),
                      );
                    }
                  : null,
            ),
          ),
      ],
    );
  }
}

class _BrewForm extends StatelessWidget {
  const _BrewForm({
    required this.state,
    required this.controller,
    required this.selectedBean,
    required this.onRecommend,
  });

  final BrewSetupState state;
  final BrewSetupController controller;
  final Bean? selectedBean;
  final VoidCallback onRecommend;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan!;
    final textTheme = Theme.of(context).textTheme;
    final remaining = selectedBean == null
        ? null
        : (selectedBean!.remainingStockG < 0
              ? 0.0
              : selectedBean!.remainingStockG);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppButton(
          label: state.aiCooldownSeconds > 0
              ? 'Coba lagi dalam ${state.aiCooldownSeconds} detik'
              : 'Rekomendasikan dengan AI',
          icon: Icons.auto_awesome_outlined,
          variant: AppButtonVariant.secondary,
          isLoading: state.isAiLoading,
          onPressed:
              state.isAiLoading ||
                  state.aiCooldownSeconds > 0 ||
                  state.fieldErrors.isNotEmpty
              ? null
              : onRecommend,
        ),
        if (state.isAiLoading) ...[
          const SizedBox(height: AppSpacing.s8),
          const AppCard(
            child: Text('Meminta saran AI. Tunggu hingga 35 detik.'),
          ),
        ],
        if (state.aiSuggestion case final suggestion?) ...[
          const SizedBox(height: AppSpacing.s12),
          _AiSuggestionCard(
            key: ObjectKey(suggestion.recommended),
            suggestion: suggestion,
            onRestore: controller.restoreBeforeAi,
          ),
        ],
        if (state.notice case final notice?) ...[
          const SizedBox(height: AppSpacing.s12),
          AppCard(variant: AppCardVariant.tinted, child: Text(notice)),
        ],
        if (plan.fromBestBrew || remaining != null) ...[
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              if (plan.fromBestBrew)
                const AppChip(label: 'Dari pengaturan terbaik', selected: true),
              const Spacer(),
              if (remaining != null)
                Text(
                  'Sisa ${formatNumber(remaining)} g',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        AppCard(
          padding: AppInsets.settingsBlock,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _BrewNumberField(
                      key: ValueKey('dose-${plan.beanId}'),
                      label: 'Dosis (g)',
                      value: formatNumber(plan.doseG),
                      errorText: state.fieldErrors['dose'],
                      decimal: true,
                      fromAi:
                          state.aiSuggestion?.highlights(AiPlanField.dose) ??
                          false,
                      onChanged: controller.updateDose,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: _BrewNumberField(
                      key: ValueKey('ratio-${plan.beanId}'),
                      label: 'Rasio (1:x)',
                      value: formatNumber(plan.ratio),
                      errorText: state.fieldErrors['ratio'],
                      decimal: true,
                      fromAi:
                          state.aiSuggestion?.highlights(AiPlanField.ratio) ??
                          false,
                      onChanged: controller.updateRatio,
                    ),
                  ),
                ],
              ),
              if (state.stockWarning case final warning?) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  warning,
                  key: const Key('insufficient-stock-warning'),
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _BrewNumberField(
                      key: ValueKey('temperature-${plan.beanId}'),
                      label: 'Suhu air (°C)',
                      value: plan.waterTempC.toString(),
                      errorText: state.fieldErrors['temperature'],
                      fromAi:
                          state.aiSuggestion?.highlights(
                            AiPlanField.temperature,
                          ) ??
                          false,
                      onChanged: controller.updateTemperature,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(child: _TotalWater(plan: plan)),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),
              _FormLabel(
                label: 'Ukuran gilingan',
                fromAi:
                    state.aiSuggestion?.highlights(AiPlanField.grind) ?? false,
              ),
              const SizedBox(height: AppSpacing.s8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final grind in Grind.values) ...[
                      AppChip(
                        label: grind.label,
                        selected: plan.grind == grind,
                        onSelected: (_) => controller.updateGrind(grind),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
              _FormLabel(
                label: 'Jumlah pouring',
                fromAi:
                    state.aiSuggestion?.highlights(AiPlanField.pouring) ??
                    false,
              ),
              const SizedBox(height: AppSpacing.s8),
              _PouringSelector(
                selected: plan.pouringCount,
                onSelected: controller.updatePouringCount,
              ),
              if (state.fieldErrors['pouring'] case final error?) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  error,
                  style: textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        Text('Tahap seduh', style: textTheme.titleLarge),
        const SizedBox(height: AppSpacing.s12),
        ...List.generate(
          plan.stages.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: _StageCard(
              plan: plan,
              stageIndex: index,
              errors: state.fieldErrors,
              controller: controller,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        AppCard(
          padding: AppInsets.settingsBlock,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrewTimeline(plan: plan),
              const SizedBox(height: AppSpacing.s20),
              BrewWaterChart(plan: plan, chartHeight: AppSizes.brewChartHeight),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalWater extends StatelessWidget {
  const _TotalWater({required this.plan});

  final BrewPlan plan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Total air', style: textTheme.labelLarge),
        const SizedBox(height: AppSpacing.s8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: AppSizes.minimumTouchTarget + AppSpacing.s8,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.navigation),
          ),
          child: Row(
            children: [
              const Icon(Icons.water_drop_outlined),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  '${formatNumber(plan.totalWaterG)} g',
                  style: textTheme.titleLarge,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PouringSelector extends StatelessWidget {
  const _PouringSelector({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (var count = 1; count <= 5; count++)
            Expanded(
              child: Semantics(
                button: true,
                selected: selected == count,
                label: '$count pouring',
                child: Material(
                  color: selected == count
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    onTap: () => onSelected(count),
                    child: SizedBox(
                      height: AppSizes.minimumTouchTarget,
                      child: Center(
                        child: ExcludeSemantics(
                          child: Text(
                            '$count',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: selected == count
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AiSuggestionCard extends StatefulWidget {
  const _AiSuggestionCard({
    required this.suggestion,
    required this.onRestore,
    super.key,
  });

  final AppliedAiSuggestion suggestion;
  final VoidCallback onRestore;

  @override
  State<_AiSuggestionCard> createState() => _AiSuggestionCardState();
}

class _AiSuggestionCardState extends State<_AiSuggestionCard> {
  bool showDetails = false;

  @override
  Widget build(BuildContext context) {
    final suggestion = widget.suggestion;
    final changes = suggestion.changes;
    return AppCard(
      variant: AppCardVariant.tinted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saran AI', style: Theme.of(context).textTheme.titleLarge),
          if (suggestion.note.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(suggestion.note),
          ],
          const SizedBox(height: AppSpacing.s12),
          if (changes.isEmpty) ...[
            const Text(
              'AI menyarankan pengaturan yang sama dengan isian saat ini',
            ),
            if (!suggestion.hasHistory) ...[
              const SizedBox(height: AppSpacing.s8),
              const Text(
                'Biji ini belum punya riwayat, jadi ini titik awal umum',
              ),
            ],
          ] else
            ...changes.map(
              (change) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: Text(
                  '${change.label}: ${change.before} ke ${change.after}',
                ),
              ),
            ),
          AppButton(
            label: showDetails ? 'Tutup detail' : 'Lihat detail',
            variant: AppButtonVariant.text,
            expand: false,
            onPressed: () => setState(() => showDetails = !showDetails),
          ),
          if (showDetails) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Tahap dibuat ulang: ${suggestion.recommended.pouringCount} pouring',
            ),
          ],
          const SizedBox(height: AppSpacing.s8),
          AppButton(
            label: 'Kembalikan',
            variant: AppButtonVariant.secondary,
            onPressed: widget.onRestore,
          ),
        ],
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.label, required this.fromAi});

  final String label;
  final bool fromAi;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.s8,
    runSpacing: AppSpacing.s8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
      if (fromAi)
        const StatusPill(label: 'AI', variant: StatusPillVariant.synced),
    ],
  );
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.plan,
    required this.stageIndex,
    required this.errors,
    required this.controller,
  });

  final BrewPlan plan;
  final int stageIndex;
  final Map<String, String> errors;
  final BrewSetupController controller;

  @override
  Widget build(BuildContext context) {
    final stage = plan.stages[stageIndex];
    final isLast = stageIndex == plan.stages.length - 1;
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      backgroundColor: BrewStageColors.forPosition(stage.position),
      padding: AppInsets.settingsBlock,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(stage.name.label, style: textTheme.titleLarge),
              ),
              Text(
                'Mulai ${formatClock(stage.startSeconds)}',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BrewNumberField(
                  key: ValueKey('duration-${plan.beanId}-$stageIndex'),
                  label: 'Durasi (detik)',
                  value: stage.durationSeconds.toString(),
                  errorText: errors['duration_$stageIndex'],
                  onChanged: (value) =>
                      controller.updateStageDuration(stageIndex, value),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: _BrewNumberField(
                  key: ValueKey('target-${plan.beanId}-$stageIndex'),
                  label: isLast ? 'Target air (sisa)' : 'Target air (g)',
                  value: formatNumber(stage.targetPourG),
                  errorText: errors['target_$stageIndex'],
                  decimal: true,
                  enabled: !isLast,
                  onChanged: (value) =>
                      controller.updateStageTarget(stageIndex, value),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Kumulatif ${formatNumber(plan.cumulativeWaterAt(stageIndex))} g',
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _BrewNumberField extends StatefulWidget {
  const _BrewNumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.decimal = false,
    this.enabled = true,
    this.fromAi = false,
    super.key,
  });

  final String label;
  final String value;
  final String? errorText;
  final bool decimal;
  final bool enabled;
  final bool fromAi;
  final ValueChanged<String> onChanged;

  @override
  State<_BrewNumberField> createState() => _BrewNumberFieldState();
}

class _BrewNumberFieldState extends State<_BrewNumberField> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _BrewNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.value != oldWidget.value ||
            (oldWidget.errorText != null && widget.errorText == null)) &&
        _normalized(_textController.text) != _normalized(widget.value)) {
      _textController.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormLabel(label: widget.label, fromAi: widget.fromAi),
        const SizedBox(height: AppSpacing.s8),
        AppTextField(
          controller: _textController,
          errorText: widget.errorText,
          enabled: widget.enabled,
          keyboardType: TextInputType.numberWithOptions(
            decimal: widget.decimal,
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

Bean? _findBean(List<Bean> beans, String? id) {
  if (id == null) {
    return null;
  }
  for (final bean in beans) {
    if (bean.id == id) {
      return bean;
    }
  }
  return null;
}

String _normalized(String value) {
  final parsed = double.tryParse(value.replaceAll(',', '.'));
  return parsed?.toString() ?? value;
}
