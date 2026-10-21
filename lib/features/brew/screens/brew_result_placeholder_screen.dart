import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_dialog.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../data/remote/ai_client.dart';
import '../../../data/repositories/brew_repo.dart';
import '../../../data/secure/session_storage.dart';
import '../../auth/session/force_logout.dart';
import '../../auth/state/auth_providers.dart';
import '../../auth/state/session_controller.dart';
import '../../beans/bean_model.dart';
import '../../beans/state/bean_providers.dart';
import '../../journal/state/journal_controller.dart';
import '../ai_brew.dart';
import '../brew_plan.dart';
import '../brew_session_result.dart';
import '../state/ai_client_provider.dart';
import '../state/brew_setup_controller.dart';
import 'brew_setup_screen.dart';

class BrewResultPlaceholderScreen extends ConsumerStatefulWidget {
  const BrewResultPlaceholderScreen({required this.result, super.key});
  final BrewSessionResult result;
  @override
  ConsumerState<BrewResultPlaceholderScreen> createState() => _ResultState();
}

class _ResultState extends ConsumerState<BrewResultPlaceholderScreen> {
  Bean? bean;
  String? userId;
  String? error;
  String? diagnosisNotice;
  Map<String, dynamic>? diagnosis;
  BrewPlan? nextPlan;
  bool diagnosisFromAi = false;
  bool loading = true, saving = false, diagnosing = false;
  int formRevision = 0;
  int? score;
  final tags = <RoasteryNoteTag>{};
  final notes = TextEditingController(), drawdown = TextEditingController();
  late final water = List.generate(
    widget.result.plan.stages.length,
    (_) => TextEditingController(),
  );

  @override
  void initState() {
    super.initState();
    notes.addListener(_formChanged);
    drawdown.addListener(_formChanged);
    for (final input in water) {
      input.addListener(_formChanged);
    }
    load();
  }

  void _formChanged() {
    setState(() {
      formRevision++;
      diagnosis = null;
      nextPlan = null;
      diagnosisNotice = null;
      diagnosisFromAi = false;
    });
  }

  @override
  void dispose() {
    notes.dispose();
    drawdown.dispose();
    for (final input in water) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final session = await ref.read(sessionControllerProvider.future);
      if (session.status != SessionStatus.authenticated ||
          session.userId == null) {
        throw StateError('Sesi tidak tersedia');
      }
      final repo = await ref.read(beanRepositoryProvider.future);
      final found = await repo.findById(
        userId: session.userId!,
        id: widget.result.plan.beanId,
      );
      if (mounted) {
        setState(() {
          userId = session.userId;
          bean = found;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Hasil seduh gagal dimuat.';
        });
      }
    }
  }

  Future<void> save() async {
    if (saving || diagnosing || score == null || tags.isEmpty) return;
    final feedback = _feedbackValues();
    if (feedback == null) return;
    final (actual, drawdownS) = feedback;
    saving = true;
    setState(() => error = null);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Simpan seduhan?',
        message: 'Data seduhan tidak dapat diubah setelah disimpan.',
        primaryLabel: 'Simpan',
        onPrimaryPressed: () => Navigator.of(dialogContext).pop(true),
        secondaryLabel: 'Batal',
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(false),
      ),
    );
    if (confirmed != true || !mounted) {
      saving = false;
      if (mounted) setState(() {});
      return;
    }
    try {
      final repo = await ref.read(brewRepositoryProvider.future);
      await repo.save(
        userId: userId!,
        result: widget.result,
        tasteScore: score!,
        tasteTags: tags,
        actualWaterG: actual,
        drawdownS: drawdownS,
        notes: notes.text,
        aiAdvice: diagnosisFromAi && diagnosis != null
            ? jsonEncode(diagnosis)
            : null,
      );
      ref.invalidate(journalBrewsProvider);
      ref.invalidate(beanListProvider);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seduhan berhasil disimpan.')),
      );
    } on BrewSaveException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Seduhan gagal disimpan. Coba lagi.');
    } finally {
      saving = false;
      if (mounted) setState(() {});
    }
  }

  (List<double?>, int?)? _feedbackValues() {
    final actual = <double?>[];
    for (final input in water) {
      final raw = input.text.trim().replaceAll(',', '.');
      final value = raw.isEmpty ? null : double.tryParse(raw);
      if (raw.isNotEmpty && (value == null || !value.isFinite || value < 0)) {
        setState(() => error = 'Air aktual harus angka tidak negatif.');
        return null;
      }
      actual.add(value);
    }
    final rawDrawdown = drawdown.text.trim();
    final drawdownS = rawDrawdown.isEmpty
        ? widget.result.drawdownS
        : int.tryParse(rawDrawdown);
    if (rawDrawdown.isNotEmpty && (drawdownS == null || drawdownS < 0)) {
      setState(() => error = 'Waktu drawdown harus detik tidak negatif.');
      return null;
    }
    return (actual, drawdownS);
  }

  bool _canShowDiagnosis(int revision) =>
      mounted &&
      formRevision == revision &&
      ModalRoute.of(context)?.isCurrent == true;

  void _showFallback(String notice) {
    final fallback = AiBrew.fallbackDiagnosis(
      plan: widget.result.plan,
      tasteScore: score!,
      tasteTags: tags.map((tag) => tag.databaseValue).toList(),
    );
    setState(() {
      diagnosis = fallback;
      nextPlan = AiBrew.planFromDiagnosis(
        base: widget.result.plan,
        diagnosis: fallback,
      );
      diagnosisNotice = notice;
      diagnosisFromAi = false;
    });
  }

  Future<void> requestDiagnosis() async {
    if (diagnosing ||
        saving ||
        score == null ||
        tags.isEmpty ||
        bean == null ||
        userId == null) {
      return;
    }
    final feedback = _feedbackValues();
    if (feedback == null) return;
    final (actual, drawdownS) = feedback;
    final revision = formRevision;
    final requestedScore = score!;
    final requestedTags = List<RoasteryNoteTag>.of(tags);
    final requestedNotes = notes.text;
    final requestedBean = bean!;
    final requestedUserId = userId!;
    final sessionStorage = ref.read(sessionStorageProvider);
    final sessionController = ref.read(sessionControllerProvider.notifier);
    setState(() {
      diagnosing = true;
      error = null;
      diagnosis = null;
      nextPlan = null;
      diagnosisNotice = null;
    });
    try {
      final repo = await ref.read(brewRepositoryProvider.future);
      final history = await repo.findAiHistory(
        userId: requestedUserId,
        beanId: requestedBean.id,
      );
      if (!_canShowDiagnosis(revision)) return;
      final payload = AiBrew.diagnosePayload(
        bean: requestedBean,
        result: widget.result,
        tasteScore: requestedScore,
        tasteTags: requestedTags,
        actualWaterG: actual,
        drawdownS: drawdownS,
        notes: requestedNotes,
        history: history,
      );
      final response = await ref
          .read(aiClientProvider)
          .diagnose(userId: requestedUserId, payload: payload);
      if (!_canShowDiagnosis(revision)) return;
      final plan = AiBrew.validDiagnosis(response)
          ? AiBrew.planFromDiagnosis(
              base: widget.result.plan,
              diagnosis: response,
            )
          : null;
      if (plan == null) {
        _showFallback(
          'Saran AI tidak dapat dipakai sebagai rencana seduh. Menampilkan saran sederhana.',
        );
      } else {
        setState(() {
          diagnosis = response;
          nextPlan = plan;
          diagnosisFromAi = true;
        });
      }
    } on AiException catch (e) {
      if (e.failure == AiFailure.unauthorized) {
        try {
          final storedSession = await sessionStorage.readSession();
          if (storedSession?.userId == requestedUserId) {
            await forceLogoutOnUnauthorized(sessionController);
          }
        } on SessionStorageException {
          // Akun aktif tidak dapat dipastikan, jadi jangan hapus sesinya.
        }
      } else if (_canShowDiagnosis(revision)) {
        _showFallback('${e.message} Menampilkan saran sederhana.');
      }
    } catch (_) {
      if (_canShowDiagnosis(revision)) {
        _showFallback('Diagnosa AI gagal. Menampilkan saran sederhana.');
      }
    } finally {
      if (mounted) setState(() => diagnosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.result.plan;
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil seduh')),
      body: SafeArea(
        top: false,
        child: loading
            ? const LoadingView(message: 'Memuat hasil seduh...')
            : error != null && bean == null
            ? Padding(
                padding: AppInsets.screen,
                child: ErrorView(message: error!, onRetry: load),
              )
            : bean == null
            ? const Padding(
                padding: AppInsets.screen,
                child: EmptyView(
                  title: 'Biji tidak tersedia',
                  message: 'Biji untuk seduhan ini tidak ditemukan.',
                  icon: Icons.coffee_outlined,
                ),
              )
            : ListView(
                padding: AppInsets.screen,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ringkasan',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${bean!.name} • ${plan.doseG} g • 1:${plan.ratio}',
                        ),
                        Text('${plan.waterTempC} °C • ${plan.grind.label}'),
                        Text('Waktu total: ${widget.result.totalTimeS} detik'),
                        if (widget.result.drawdownS != null)
                          Text('Drawdown: ${widget.result.drawdownS} detik'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    'Tahap seduh',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ...List.generate(plan.stages.length, (index) {
                    final stage = plan.stages[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stage.name.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Target ${stage.startSeconds} detik • ${plan.cumulativeWaterAt(index)} g kumulatif • ${stage.targetPourG} g tuang',
                            ),
                            AppTextField(
                              controller: water[index],
                              label: 'Air aktual (g) • opsional',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (widget.result.drawdownS == null) ...[
                    AppTextField(
                      controller: drawdown,
                      label: 'Waktu drawdown (detik) • opsional',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],
                  Text(
                    'Skor rasa',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Wrap(
                    spacing: AppSpacing.s8,
                    children: List.generate(
                      5,
                      (index) => AppChip(
                        label: '${index + 1}',
                        selected: score == index + 1,
                        onSelected: (_) {
                          score = index + 1;
                          _formChanged();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    'Tag rasa',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Wrap(
                    spacing: AppSpacing.s8,
                    children: RoasteryNoteTag.values
                        .map(
                          (tag) => AppChip(
                            label: tag.label,
                            selected: tags.contains(tag),
                            onSelected: (selected) {
                              if (selected) {
                                tags.add(tag);
                              } else {
                                tags.remove(tag);
                              }
                              _formChanged();
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Perbandingan rasa',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Roastery: ${bean!.roasteryNotesTags.isEmpty ? '-' : bean!.roasteryNotesTags.join(', ')}',
                        ),
                        if (bean!.roasteryNotesText case final text?)
                          Text(text),
                        Text(
                          'Rasamu: ${tags.isEmpty ? '-' : tags.map((tag) => tag.label).join(', ')}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  AppTextField(
                    controller: notes,
                    label: 'Catatan bebas • opsional',
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    'Biaya seduhan: ${brewCost(plan.doseG, bean!.priceIdrPerKg)?.toStringAsFixed(0) ?? '-'} IDR',
                  ),
                  if (error != null) Text(error!),
                  if (diagnosis != null) ...[
                    const SizedBox(height: AppSpacing.s16),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          StatusPill(
                            label: diagnosisFromAi
                                ? 'Diagnosa AI'
                                : 'Saran sederhana',
                            variant: diagnosisFromAi
                                ? StatusPillVariant.synced
                                : StatusPillVariant.warning,
                          ),
                          if (diagnosisNotice != null) ...[
                            const SizedBox(height: AppSpacing.s8),
                            Text(diagnosisNotice!),
                          ],
                          const SizedBox(height: AppSpacing.s8),
                          Text(AiBrew.diagnosisSummary(diagnosis!)),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            'Saran, bukan kepastian. Coba dan catat hasilnya.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (nextPlan != null) ...[
                      const SizedBox(height: AppSpacing.s8),
                      AppButton(
                        label: 'Terapkan ke seduhan berikutnya',
                        variant: AppButtonVariant.secondary,
                        onPressed: saving || diagnosing
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      BrewSetupScreen(initialPlan: nextPlan),
                                ),
                              ),
                      ),
                    ],
                  ] else if (score == null || tags.isEmpty) ...[
                    const SizedBox(height: AppSpacing.s16),
                    const AppCard(
                      child: Text(
                        'Pilih skor dan tag rasa untuk meminta diagnosa.',
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s16),
                  AppButton(
                    label: 'Simpan',
                    isLoading: saving,
                    onPressed:
                        score != null &&
                            tags.isNotEmpty &&
                            !saving &&
                            !diagnosing
                        ? save
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  AppButton(
                    label: 'Minta Diagnosa AI',
                    variant: AppButtonVariant.secondary,
                    isLoading: diagnosing,
                    onPressed:
                        score != null &&
                            tags.isNotEmpty &&
                            !saving &&
                            !diagnosing
                        ? requestDiagnosis
                        : null,
                  ),
                ],
              ),
      ),
    );
  }
}
