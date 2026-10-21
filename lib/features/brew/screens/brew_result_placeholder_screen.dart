import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_dialog.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/notifications/notification_coordinator.dart';
import '../../../data/repositories/brew_repo.dart';
import '../../auth/state/session_controller.dart';
import '../../beans/bean_model.dart';
import '../../beans/state/bean_providers.dart';
import '../../journal/state/journal_controller.dart';
import '../../journal/screens/brew_detail_screen.dart';
import '../brew_session_result.dart';
import '../state/brew_setup_controller.dart';

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
  bool loading = true, saving = false;
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
    load();
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
    if (saving || score == null || tags.isEmpty) return;
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
      final beforeStock = await repo.remainingStockG(
        userId: userId!,
        beanId: widget.result.plan.beanId,
      );
      final brewId = await repo.save(
        userId: userId!,
        result: widget.result,
        tasteScore: score!,
        tasteTags: tags,
        actualWaterG: actual,
        drawdownS: drawdownS,
        notes: notes.text,
      );
      try {
        final afterStock = await repo.remainingStockG(
          userId: userId!,
          beanId: widget.result.plan.beanId,
        );
        if (afterStock < beforeStock) {
          await (await ref.read(
            notificationCoordinatorProvider.future,
          )).showStockCrossing(
            userId: userId!,
            beanName: bean?.name ?? 'biji',
            beforeG: beforeStock,
            afterG: afterStock,
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Seduhan tersimpan, tetapi notifikasi stok belum dikirim.',
              ),
            ),
          );
        }
      }
      ref.invalidate(journalBrewsProvider);
      ref.invalidate(beanListProvider);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.popUntil((route) => route.isFirst);
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => BrewDetailScreen(brewId: brewId),
        ),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Seduhan tersimpan')),
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
                          setState(() {});
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
                              setState(() {});
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
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    'Diagnosa AI tersedia setelah menyimpan',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  AppButton(
                    label: 'Simpan',
                    isLoading: saving,
                    onPressed: score != null && tags.isNotEmpty && !saving
                        ? save
                        : null,
                  ),
                ],
              ),
      ),
    );
  }
}
