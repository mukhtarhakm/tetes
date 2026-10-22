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

    return ListView(
      padding: AppInsets.screen,
      children: [
        AppDropdownField<Bean>(
          label: 'Biji kopi',
          items: state.beans,
          itemLabel: (bean) => bean.name,
          value: selectedBean,
          hintText: 'Pilih biji aktif',
          onChanged: (bean) => controller.selectBean(bean?.id),
        ),
        const SizedBox(height: AppSpacing.s20),
        if (state.isPlanLoading)
          const SizedBox(
            height: AppSizes.statePreviewHeight,
            child: LoadingView(message: 'Memuat rencana seduh...'),
          )
        else if (state.plan == null)
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
            onRecommend: () async {
              await controller.recommend(
                isScreenCurrent: () =>
                    context.mounted &&
                    ModalRoute.of(context)?.isCurrent == true,
              );
            },
          ),
      ],
    );
  }
}

class _BrewForm extends StatelessWidget {
  const _BrewForm({
    required this.state,
    required this.controller,
    required this.onRecommend,
  });

  final BrewSetupState state;
  final BrewSetupController controller;
  final VoidCallback onRecommend;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan!;
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
        const SizedBox(height: AppSpacing.s20),
        if (plan.fromBestBrew) ...[
          const AppChip(label: 'Dari pengaturan terbaik', selected: true),
          const SizedBox(height: AppSpacing.s16),
        ],
        _BrewNumberField(
          key: ValueKey('dose-${plan.beanId}'),
          label: 'Dosis (g)',
          value: _formatNumber(plan.doseG),
          errorText: state.fieldErrors['dose'],
          decimal: true,
          fromAi: state.aiSuggestion?.highlights(AiPlanField.dose) ?? false,
          onChanged: controller.updateDose,
        ),
        const SizedBox(height: AppSpacing.s16),
        _BrewNumberField(
          key: ValueKey('ratio-${plan.beanId}'),
          label: 'Rasio (1:x)',
          value: _formatNumber(plan.ratio),
          errorText: state.fieldErrors['ratio'],
          decimal: true,
          fromAi: state.aiSuggestion?.highlights(AiPlanField.ratio) ?? false,
          onChanged: controller.updateRatio,
        ),
        const SizedBox(height: AppSpacing.s16),
        _BrewNumberField(
          key: ValueKey('temperature-${plan.beanId}'),
          label: 'Suhu air (°C)',
          value: plan.waterTempC.toString(),
          errorText: state.fieldErrors['temperature'],
          fromAi:
              state.aiSuggestion?.highlights(AiPlanField.temperature) ?? false,
          onChanged: controller.updateTemperature,
        ),
        const SizedBox(height: AppSpacing.s16),
        AppCard(
          variant: AppCardVariant.tinted,
          child: Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.water_drop_outlined),
              Text(
                'Total air',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                '${_formatNumber(plan.totalWaterG)} g',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        _FormLabel(
          label: 'Ukuran gilingan',
          fromAi: state.aiSuggestion?.highlights(AiPlanField.grind) ?? false,
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: Grind.values
              .map(
                (grind) => AppChip(
                  label: grind.label,
                  selected: plan.grind == grind,
                  onSelected: (_) => controller.updateGrind(grind),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.s20),
        _FormLabel(
          label: 'Jumlah pouring',
          fromAi: state.aiSuggestion?.highlights(AiPlanField.pouring) ?? false,
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: List.generate(
            5,
            (index) => AppChip(
              label: '${index + 1}',
              selected: plan.pouringCount == index + 1,
              onSelected: (_) => controller.updatePouringCount(index + 1),
            ),
          ),
        ),
        if (state.fieldErrors['pouring'] case final error?) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            error,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.s24),
        Text('Tahap seduh', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.s12),
        ...List.generate(
          plan.stages.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s16),
            child: _StageCard(
              plan: plan,
              stageIndex: index,
              errors: state.fieldErrors,
              controller: controller,
            ),
          ),
        ),
        AppCard(child: BrewTimeline(plan: plan)),
        const SizedBox(height: AppSpacing.s16),
        AppCard(child: BrewWaterChart(plan: plan)),
        const SizedBox(height: AppSpacing.s24),
        AppButton(
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
      ],
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
    return AppCard(
      backgroundColor: BrewStageColors.forPosition(stage.position),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                stage.name.label,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                'Mulai ${_formatTime(stage.startSeconds)}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          _BrewNumberField(
            key: ValueKey('duration-${plan.beanId}-$stageIndex'),
            label: 'Durasi (detik)',
            value: stage.durationSeconds.toString(),
            errorText: errors['duration_$stageIndex'],
            onChanged: (value) =>
                controller.updateStageDuration(stageIndex, value),
          ),
          const SizedBox(height: AppSpacing.s12),
          _BrewNumberField(
            key: ValueKey('target-${plan.beanId}-$stageIndex'),
            label: isLast
                ? 'Target air per tuang (sisa)'
                : 'Target air per tuang (g)',
            value: _formatNumber(stage.targetPourG),
            errorText: errors['target_$stageIndex'],
            decimal: true,
            enabled: !isLast,
            onChanged: (value) =>
                controller.updateStageTarget(stageIndex, value),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            'Target kumulatif: ${_formatNumber(plan.cumulativeWaterAt(stageIndex))} g',
            style: Theme.of(context).textTheme.bodyLarge,
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

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String _normalized(String value) {
  final parsed = double.tryParse(value.replaceAll(',', '.'));
  return parsed?.toString() ?? value;
}

String _formatTime(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
