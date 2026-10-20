import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_dialog.dart';
import '../../../core/ui/score_chart.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../journal/screens/brew_detail_screen.dart';
import '../bean_model.dart';
import '../state/bean_providers.dart';
import '../../brew/screens/brew_setup_screen.dart';
import 'bean_form_screen.dart';

class BeanDetailScreen extends ConsumerWidget {
  const BeanDetailScreen({required this.beanId, super.key});

  final String beanId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bean = ref.watch(beanDetailProvider(beanId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail biji')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: AppInsets.screen,
          child: bean.when(
            loading: () => const LoadingView(message: 'Memuat detail biji...'),
            error: (_, _) => ErrorView(
              message: 'Detail biji tidak dapat dimuat.',
              onRetry: () => ref.invalidate(beanDetailProvider(beanId)),
            ),
            data: (item) => item == null
                ? EmptyView(
                    title: 'Biji tidak ditemukan',
                    message: 'Data biji ini sudah tidak tersedia.',
                    icon: Icons.coffee_outlined,
                    actionLabel: 'Kembali',
                    onActionPressed: () => Navigator.of(context).pop(),
                  )
                : _BeanDetailContent(bean: item),
          ),
        ),
      ),
    );
  }
}

class _BeanDetailContent extends ConsumerWidget {
  const _BeanDetailContent({required this.bean});

  final Bean bean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mutation = ref.watch(beanMutationProvider);
    return ListView(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(bean.name, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: AppSpacing.s12),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  AppChip(label: bean.species.label),
                  if (bean.roastLevel != null)
                    AppChip(label: bean.roastLevel!.label),
                  StatusPill(
                    label: bean.isLowStock ? 'Stok menipis' : 'Stok aman',
                    variant: bean.isLowStock
                        ? StatusPillVariant.warning
                        : StatusPillVariant.synced,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),
              _DetailRow(label: 'Roastery', value: bean.roastery),
              _DetailRow(
                label: 'Roasting sendiri',
                value: bean.isSelfRoasted ? 'Ya' : 'Tidak',
              ),
              _DetailRow(label: 'Tipe', value: bean.beanType?.label),
              if (bean.species == BeanSpecies.campuran)
                _DetailRow(label: 'Arabika', value: '${bean.arabicaPercent}%'),
              _DetailRow(label: 'Asal', value: bean.origin),
              _DetailRow(label: 'Proses', value: _processLabel(bean)),
              _DetailRow(label: 'Tanggal roasting', value: bean.roastDate),
              _DetailRow(
                label: 'Ukuran kemasan',
                value: bean.packSizeG == null
                    ? 'Ukuran kemasan belum diisi'
                    : '${_formatNumber(bean.packSizeG!)} g',
              ),
              _DetailRow(
                label: 'Harga kemasan',
                value: bean.priceOriginal == null
                    ? null
                    : '${_formatNumber(bean.priceOriginal!)} ${bean.currency ?? ''}',
              ),
              _DetailRow(label: 'Kurs saat input', value: _fxLabel(bean)),
              _DetailRow(
                label: 'Harga rupiah per kemasan',
                value: _packagePriceIdr(bean),
              ),
              _DetailRow(
                label: 'Harga rupiah per kg',
                value: bean.priceIdrPerKg == null
                    ? null
                    : formatIdr(bean.priceIdrPerKg!),
              ),
              _DetailRow(
                label: 'Stok awal',
                value: '${_formatNumber(bean.initialStockG)} g',
              ),
              _DetailRow(
                label: 'Stok tersisa',
                value: '${_formatNumber(bean.remainingStockG)} g',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        AppCard(
          variant: AppCardVariant.tinted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tasting notes roastery',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s12),
              if (bean.roasteryNotesTags.isEmpty)
                Text(
                  'Belum ada tag rasa.',
                  style: Theme.of(context).textTheme.bodyLarge,
                )
              else
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: bean.roasteryNotesTags
                      .map(
                        (tag) =>
                            AppChip(label: RoasteryNoteTag.labelForValue(tag)),
                      )
                      .toList(),
                ),
              if (bean.roasteryNotesText != null) ...[
                const SizedBox(height: AppSpacing.s12),
                Text(
                  bean.roasteryNotesText!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pengaturan terbaik',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                bean.bestBrewId == null
                    ? 'Belum ada seduhan untuk biji ini.'
                    : 'Pengaturan terbaik tersedia dari jurnal seduhan.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.s16),
              AppButton(
                label: 'Seduh dengan ini',
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => BrewSetupScreen(initialBeanId: bean.id),
                  ),
                ),
                icon: Icons.coffee_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grafik Skor Rasa',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Tren skor rasa dari seduhan aktif biji ini.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
              const SizedBox(height: AppSpacing.s16),
              ref.watch(beanActiveBrewsProvider(bean.id)).when(
                    data: (brews) {
                      final scores = brews.map((b) => b.tasteScore).toList();
                      return ScoreChart(scores: scores);
                    },
                    loading: () => const SizedBox(
                      height: ScoreChartTokens.defaultHeight,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => const SizedBox(
                      height: ScoreChartTokens.defaultHeight,
                      child: Center(child: Text('Gagal memuat grafik skor.')),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Riwayat Seduhan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s12),
              ref.watch(beanHistoryBrewsProvider(bean.id)).when(
                    data: (brews) {
                      if (brews.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s12,
                          ),
                          child: Text(
                            'Belum ada seduhan untuk biji ini.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.inkSoft),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: brews.length,
                        separatorBuilder: (_, _) =>
                            const Divider(color: AppColors.divider),
                        itemBuilder: (context, index) {
                          final item = brews[index];
                          final ratioText = item.ratio % 1 == 0
                              ? '1:${item.ratio.toInt()}'
                              : '1:${item.ratio.toStringAsFixed(1)}';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${_formatDate(item.brewedAtUtc)} • ★ ${item.tasteScore}/5',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${item.doseG.toStringAsFixed(1)}g • $ratioText • ${item.waterTempC}°C',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.inkSoft),
                            ),
                            trailing: Wrap(
                              spacing: AppSpacing.s4,
                              children: [
                                if (item.isCancelled)
                                  const StatusPill(
                                    label: 'Dibatalkan',
                                    variant: StatusPillVariant.warning,
                                  ),
                                const Icon(Icons.chevron_right_rounded),
                              ],
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    BrewDetailScreen(brewId: item.id),
                              ),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(AppSpacing.s16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) =>
                        const Text('Gagal memuat riwayat seduhan.'),
                  ),
            ],
          ),
        ),
        if (mutation.hasError) ...[
          const SizedBox(height: AppSpacing.s16),
          Text(
            'Perubahan biji gagal disimpan. Silakan coba lagi.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.s24),
        AppButton(
          label: 'Ubah',
          variant: AppButtonVariant.secondary,
          icon: Icons.edit_outlined,
          onPressed: mutation.isLoading ? null : () => _openEdit(context, ref),
        ),
        const SizedBox(height: AppSpacing.s8),
        AppButton(
          label: 'Arsipkan',
          variant: AppButtonVariant.text,
          isLoading: mutation.isLoading,
          onPressed: mutation.isLoading
              ? null
              : () => _confirmArchive(context, ref),
        ),
      ],
    );
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => BeanFormScreen(initialBean: bean)),
    );
    if (saved == true) {
      ref.invalidate(beanDetailProvider(bean.id));
    }
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Arsipkan biji?',
        message:
            'Biji akan disembunyikan dari daftar, tetapi riwayat seduhan tetap tersimpan.',
        primaryLabel: 'Arsipkan',
        onPrimaryPressed: () => Navigator.of(dialogContext).pop(true),
        secondaryLabel: 'Batal',
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(false),
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }

    final archived = await ref
        .read(beanMutationProvider.notifier)
        .archive(bean.id);
    if (archived && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Biji berhasil diarsipkan.')),
        );
      Navigator.of(context).pop();
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Text(
              value == null || value!.isEmpty ? '—' : value!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String? _processLabel(Bean bean) {
  final process = bean.process;
  if (process == null) {
    return null;
  }
  if (process != BeanProcess.lainnya ||
      bean.processCustom == null ||
      bean.processCustom!.isEmpty) {
    return process.label;
  }
  return '${process.label} — ${bean.processCustom}';
}

String? _fxLabel(Bean bean) {
  if (bean.fxRate == null || bean.fxDate == null || bean.currency == null) {
    return null;
  }
  return '1 ${bean.currency} = ${formatIdr(bean.fxRate!)} • ${bean.fxDate}';
}

String? _packagePriceIdr(Bean bean) {
  if (bean.priceOriginal == null || bean.fxRate == null) {
    return null;
  }
  return formatIdr(bean.priceOriginal! * bean.fxRate!);
}

String _formatDate(String utcString) {
  final dt = DateTime.tryParse(utcString)?.toLocal();
  if (dt == null) return utcString;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
}
