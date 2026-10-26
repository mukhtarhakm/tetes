import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_dialog.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/ui/custom_taste_chip.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/notifications/notification_coordinator.dart';
import '../../../data/repositories/brew_repo.dart';
import '../../auth/state/session_controller.dart';
import '../../beans/bean_model.dart';
import '../../beans/state/bean_providers.dart';
import '../../journal/state/journal_controller.dart';
import '../../journal/screens/brew_detail_screen.dart';
import '../brew_session_result.dart';
import '../custom_taste_tags.dart';
import '../state/brew_setup_controller.dart';

class BrewResultScreen extends ConsumerStatefulWidget {
  const BrewResultScreen({required this.result, super.key});
  final BrewSessionResult result;
  @override
  ConsumerState<BrewResultScreen> createState() => _ResultState();
}

class _ResultState extends ConsumerState<BrewResultScreen> {
  Bean? bean;
  String? userId;
  String? error;
  bool loading = true, saving = false, stockRejected = false;
  int? score;
  final tags = <RoasteryNoteTag>{};
  final customTags = <String>[];
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
      stockRejected = false;
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
        customTasteTags: customTags,
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
    } on InsufficientStockException catch (e) {
      if (mounted) {
        setState(() {
          stockRejected = true;
          error = e.message;
        });
      }
    } on BrewSaveException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Seduhan gagal disimpan. Coba lagi.');
    } finally {
      saving = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _addCustomTasteTag() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _CustomTasteTagDialog(existing: List.of(customTags)),
    );
    if (result != null && mounted) {
      setState(
        () => customTags
          ..clear()
          ..addAll(result),
      );
    }
  }

  /// Kolom timbangan berisi angka kumulatif di timbangan. Yang disimpan tetap
  /// air per tahap (selisih dengan angka terisi sebelumnya), sehingga format
  /// data, sinkronisasi, dan diagnosa AI tidak berubah.
  (List<double?>, int?)? _feedbackValues() {
    final actual = <double?>[];
    var previousCumulative = 0.0;
    for (final input in water) {
      final raw = input.text.trim().replaceAll(',', '.');
      final value = raw.isEmpty ? null : double.tryParse(raw);
      if (raw.isNotEmpty && (value == null || !value.isFinite || value < 0)) {
        setState(() => error = 'Angka timbangan harus angka tidak negatif.');
        return null;
      }
      if (value == null) {
        actual.add(null);
        continue;
      }
      if (value < previousCumulative) {
        setState(
          () => error = 'Angka timbangan harus bertambah di tiap tahap.',
        );
        return null;
      }
      actual.add(double.parse((value - previousCumulative).toStringAsFixed(2)));
      previousCumulative = value;
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

  String _n(num v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  String _formatDuration(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  String _rupiah(num value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return 'Rp $buffer';
  }

  Widget _summaryCard(BuildContext context) {
    final plan = widget.result.plan;
    final textTheme = Theme.of(context).textTheme;
    final cost = brewCost(plan.doseG, bean!.priceIdrPerKg);
    Widget stat(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  bean!.name,
                  style: textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (cost != null) ...[
                const SizedBox(width: AppSpacing.s12),
                Text(
                  'Biaya ${_rupiah(cost)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.navigation),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.s16,
              runSpacing: AppSpacing.s12,
              children: [
                stat('Dosis', '${_n(plan.doseG)} g'),
                stat('Rasio', '1:${_n(plan.ratio)}'),
                stat('Suhu', '${plan.waterTempC}°C'),
                stat('Waktu', _formatDuration(widget.result.totalTimeS)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            [
              'Gilingan ${plan.grind.label}',
              if (widget.result.drawdownS != null)
                'drawdown ${widget.result.drawdownS} detik',
            ].join(' · '),
            style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _scoreRow(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final value = index + 1;
        final selected = score == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: index == 0 ? 0 : AppSpacing.s8),
            child: Semantics(
              button: true,
              selected: selected,
              label: 'Skor $value',
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.navigation),
                onTap: () => setState(() => score = value),
                child: AnimatedContainer(
                  duration: AppDurations.feedback,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.stage1Soft : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.navigation),
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: ExcludeSemantics(
                    child: Text(
                      '$value',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _scaleCard(BuildContext context) {
    final plan = widget.result.plan;
    final textTheme = Theme.of(context).textTheme;
    final last = plan.stages.length - 1;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: 'Timbangan tiap tahap (g) ',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: '· opsional',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Isi angka kumulatif di timbangan. Tuangan tiap tahap dihitung otomatis.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.s12),
          ...List.generate(plan.stages.length, (index) {
            final stage = plan.stages[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == last ? 0 : AppSpacing.s12,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          index == last && last > 0
                              ? '${stage.name.label} · total'
                              : stage.name.label,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'target ${_n(plan.cumulativeWaterAt(index))} g',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  SizedBox(
                    width: 120,
                    child: AppTextField(
                      controller: water[index],
                      hintText: _n(plan.cumulativeWaterAt(index)),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (widget.result.drawdownS == null) ...[
            const SizedBox(height: AppSpacing.s16),
            AppTextField(
              controller: drawdown,
              label: 'Waktu drawdown (detik) • opsional',
              keyboardType: TextInputType.number,
            ),
          ],
        ],
      ),
    );
  }

  Widget _notesTile(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.innerCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            0,
            AppSpacing.s16,
            AppSpacing.s16,
          ),
          title: Text.rich(
            TextSpan(
              text: 'Catatan ',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              children: [
                TextSpan(
                  text: '· opsional',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          children: [AppTextField(controller: notes, maxLines: 3)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.result.plan;
    final textTheme = Theme.of(context).textTheme;
    Widget heading(String title, String hint) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Text.rich(
        TextSpan(
          text: '$title ',
          style: textTheme.titleLarge,
          children: [
            TextSpan(
              text: hint,
              style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );

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
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s20,
                        AppSpacing.s4,
                        AppSpacing.s20,
                        AppSpacing.s16,
                      ),
                      children: [
                        _summaryCard(context),
                        const SizedBox(height: AppSpacing.s20),
                        heading('Gimana rasanya?', 'pilih skor'),
                        _scoreRow(context),
                        const SizedBox(height: AppSpacing.s20),
                        heading('Rasanya seperti apa?', 'pilih minimal satu'),
                        Wrap(
                          spacing: AppSpacing.s8,
                          runSpacing: AppSpacing.s8,
                          children: [
                            ...RoasteryNoteTag.values.map(
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
                            ),
                            ...customTags.map(
                              (tag) => CustomTasteChip(
                                label: tag,
                                onRemove: () =>
                                    setState(() => customTags.remove(tag)),
                              ),
                            ),
                            if (customTags.length < 3)
                              AddCustomTasteChip(onPressed: _addCustomTasteTag),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          [
                            'Kata roastery: ${bean!.roasteryNotesTags.isEmpty ? '-' : bean!.roasteryNotesTags.join(', ')}',
                            'Rasamu: ${tags.isEmpty && customTags.isEmpty ? '-' : [...tags.map((tag) => tag.label), ...customTags].join(', ')}',
                          ].join(' · '),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.inkSoft,
                            height: 1.4,
                          ),
                        ),
                        if (bean!.roasteryNotesText case final text?)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.s4),
                            child: Text(
                              text,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.s20),
                        _scaleCard(context),
                        const SizedBox(height: AppSpacing.s12),
                        _notesTile(context),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s20,
                      AppSpacing.s8,
                      AppSpacing.s20,
                      AppSpacing.s16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (error != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.s8,
                            ),
                            child: Text(
                              error!,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        if (plan.doseG > bean!.remainingStockG)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.s8,
                            ),
                            child: Text(
                              InsufficientStockException(
                                bean!.name,
                                bean!.remainingStockG,
                                plan.doseG,
                              ).message,
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        AppButton(
                          label: 'Simpan',
                          isLoading: saving,
                          onPressed:
                              score != null &&
                                  tags.isNotEmpty &&
                                  !saving &&
                                  !stockRejected &&
                                  plan.doseG <= bean!.remainingStockG
                              ? save
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          'Diagnosa AI tersedia setelah menyimpan',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Dialog "Rasa lain". Controller dimiliki dan dibuang oleh State dialog
/// sendiri, bukan oleh pemanggil, supaya tidak dibuang saat animasi tutup.
class _CustomTasteTagDialog extends StatefulWidget {
  const _CustomTasteTagDialog({required this.existing});
  final List<String> existing;

  @override
  State<_CustomTasteTagDialog> createState() => _CustomTasteTagDialogState();
}

class _CustomTasteTagDialogState extends State<_CustomTasteTagDialog> {
  final _input = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final normalized = normalizeCustomTasteTags([
        ...widget.existing,
        _input.text,
      ]);
      if (normalized.length == widget.existing.length) {
        setState(() => _error = 'Rasa ini sudah ditambahkan.');
        return;
      }
      Navigator.of(context).pop(normalized);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Rasa lain',
      message: 'Tambahkan rasa yang kamu rasakan.',
      content: AppTextField(
        controller: _input,
        label: 'Rasa lain',
        maxLength: 20,
        maxLengthEnforcement: MaxLengthEnforcement.none,
        errorText: _error,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      primaryLabel: 'Tambah',
      onPrimaryPressed: _submit,
      secondaryLabel: 'Batal',
      onSecondaryPressed: () => Navigator.of(context).pop(),
    );
  }
}
