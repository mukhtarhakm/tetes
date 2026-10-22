import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/utils/format_ratio.dart';
import '../brew_comparison_service.dart';
import '../journal_model.dart';
import '../state/journal_controller.dart';

class BrewCompareScreen extends ConsumerWidget {
  const BrewCompareScreen({
    required this.brewId1,
    required this.brewId2,
    super.key,
  });

  final String brewId1;
  final String brewId2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brew1Async = ref.watch(brewDetailProvider(brewId1));
    final brew2Async = ref.watch(brewDetailProvider(brewId2));

    return Scaffold(
      appBar: AppBar(title: const Text('Bandingkan Seduhan')),
      body: SafeArea(
        child: brew1Async.when(
          loading: () =>
              const LoadingView(message: 'Memuat data perbandingan...'),
          error: (_, _) => Padding(
            padding: AppInsets.screen,
            child: ErrorView(
              message: 'Gagal memuat data seduhan.',
              onRetry: () {
                ref.invalidate(brewDetailProvider(brewId1));
                ref.invalidate(brewDetailProvider(brewId2));
              },
            ),
          ),
          data: (data1) {
            return brew2Async.when(
              loading: () =>
                  const LoadingView(message: 'Memuat data perbandingan...'),
              error: (_, _) => Padding(
                padding: AppInsets.screen,
                child: ErrorView(
                  message: 'Gagal memuat data seduhan kedua.',
                  onRetry: () {
                    ref.invalidate(brewDetailProvider(brewId1));
                    ref.invalidate(brewDetailProvider(brewId2));
                  },
                ),
              ),
              data: (data2) {
                if (data1 == null || data2 == null) {
                  return const Padding(
                    padding: AppInsets.screen,
                    child: EmptyView(
                      title: 'Data tidak lengkap',
                      message:
                          'Salah satu atau kedua data seduhan tidak ditemukan.',
                      icon: Icons.coffee_outlined,
                    ),
                  );
                }

                // Seduhan lebih lama di kiri, lebih baru di kanan berdasarkan brewed_at_utc
                final dt1 =
                    DateTime.tryParse(data1.item.brewedAtUtc) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final dt2 =
                    DateTime.tryParse(data2.item.brewedAtUtc) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final isFirstOlder =
                    dt1.isBefore(dt2) ||
                    (dt1.isAtSameMomentAs(dt2) &&
                        data1.item.seq <= data2.item.seq);

                final older = isFirstOlder ? data1 : data2;
                final newer = isFirstOlder ? data2 : data1;

                return _CompareContent(older: older, newer: newer);
              },
            );
          },
        ),
      ),
    );
  }
}

class _CompareContent extends StatelessWidget {
  const _CompareContent({required this.older, required this.newer});

  final BrewDetailData older;
  final BrewDetailData newer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDifferentBeans = older.item.beanId != newer.item.beanId;
    final summaryText = BrewComparisonService.generateComparisonSummary(
      older: older,
      newer: newer,
    );

    return ListView(
      padding: AppInsets.screen,
      children: [
        // Catatan Biji Berbeda jika biji tidak sama
        if (isDifferentBeans) ...[
          Container(
            padding: AppInsets.card,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.primary),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.ink,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Biji berbeda',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'Kedua seduhan menggunakan biji kopi yang berbeda.',
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
          const SizedBox(height: AppSpacing.s16),
        ],

        // Kartu Ringkasan Hasil (Aturan Sederhana Murni)
        AppCard(
          variant: AppCardVariant.tinted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ringkasan Perbandingan',
                style: textTheme.labelLarge?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                summaryText,
                style: textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Tabel Perbandingan
        Text('Perbandingan Parameter', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Header Kolom
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s12,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.card),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Parameter',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Seduhan Lama\n(${_formatDate(older.item.brewedAtUtc)})',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text(
                        'Seduhan Baru\n(${_formatDate(newer.item.brewedAtUtc)})',
                        style: textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.divider, height: 1),

              // Baris-baris perbandingan
              _CompareRow(
                label: 'Biji',
                val1: older.item.beanName,
                val2: newer.item.beanName,
                isDifferent: older.item.beanId != newer.item.beanId,
              ),
              _CompareRow(
                label: 'Dosis',
                val1: '${older.item.doseG.toStringAsFixed(1)} g',
                val2: '${newer.item.doseG.toStringAsFixed(1)} g',
                isDifferent:
                    (older.item.doseG - newer.item.doseG).abs() > 0.0001,
              ),
              _CompareRow(
                label: 'Rasio',
                val1: formatRatio(older.item.ratio),
                val2: formatRatio(newer.item.ratio),
                isDifferent:
                    (older.item.ratio - newer.item.ratio).abs() > 0.0001,
              ),
              _CompareRow(
                label: 'Suhu air',
                val1: '${older.item.waterTempC}°C',
                val2: '${newer.item.waterTempC}°C',
                isDifferent: older.item.waterTempC != newer.item.waterTempC,
              ),
              _CompareRow(
                label: 'Ukuran grind',
                val1: older.item.grind.label,
                val2: newer.item.grind.label,
                isDifferent: older.item.grind != newer.item.grind,
              ),
              _CompareRow(
                label: 'Jumlah tahap',
                val1: '${older.stages.length} tahap',
                val2: '${newer.stages.length} tahap',
                isDifferent: older.stages.length != newer.stages.length,
              ),
              _CompareRow(
                label: 'Total waktu',
                val1: _formatSeconds(older.item.totalTimeS),
                val2: _formatSeconds(newer.item.totalTimeS),
                isDifferent: older.item.totalTimeS != newer.item.totalTimeS,
              ),
              _CompareRow(
                label: 'Drawdown',
                val1: older.finalDrawdownS != null
                    ? '${older.finalDrawdownS}s'
                    : '—',
                val2: newer.finalDrawdownS != null
                    ? '${newer.finalDrawdownS}s'
                    : '—',
                isDifferent: older.finalDrawdownS != newer.finalDrawdownS,
              ),
              _CompareRow(
                label: 'Skor rasa',
                val1: '★ ${older.item.tasteScore}/5',
                val2: '★ ${newer.item.tasteScore}/5',
                isDifferent: older.item.tasteScore != newer.item.tasteScore,
              ),
              _CompareRow(
                label: 'Tag rasa',
                val1: older.item.tasteTags.isEmpty
                    ? '—'
                    : older.item.tasteTags.join(', '),
                val2: newer.item.tasteTags.isEmpty
                    ? '—'
                    : newer.item.tasteTags.join(', '),
                isDifferent: _areTagsDifferent(
                  older.item.tasteTags,
                  newer.item.tasteTags,
                ),
              ),
              _CompareRow(
                label: 'Biaya',
                val1: older.item.costIdr != null
                    ? 'Rp ${older.item.costIdr!.toStringAsFixed(0)}'
                    : '—',
                val2: newer.item.costIdr != null
                    ? 'Rp ${newer.item.costIdr!.toStringAsFixed(0)}'
                    : '—',
                isDifferent: older.item.costIdr != newer.item.costIdr,
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s32),
      ],
    );
  }

  static bool _areTagsDifferent(List<String> tags1, List<String> tags2) {
    if (tags1.isEmpty && tags2.isEmpty) return false;
    final set1 = tags1.toSet();
    final set2 = tags2.toSet();
    return set1.length != set2.length || !set1.containsAll(set2);
  }

  static String _formatSeconds(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  static String _formatDate(String utcString) {
    final dt = DateTime.tryParse(utcString)?.toLocal();
    if (dt == null) return utcString;
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.label,
    required this.val1,
    required this.val2,
    required this.isDifferent,
    this.isLast = false,
  });

  final String label;
  final String val1;
  final String val2;
  final bool isDifferent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final primaryContainer = Theme.of(context).colorScheme.primaryContainer;
    final backgroundColor = isDifferent
        ? primaryContainer.withValues(alpha: 0.35)
        : Colors.transparent;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: isLast
            ? const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.card),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: isDifferent ? FontWeight.bold : null,
                    ),
                  ),
                ),
                if (isDifferent) ...[
                  const SizedBox(width: AppSpacing.s4),
                  const StatusPill(
                    label: 'Beda',
                    variant: StatusPillVariant.warning,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            flex: 4,
            child: Text(
              val1,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: isDifferent ? FontWeight.bold : null,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            flex: 4,
            child: Text(
              val2,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: isDifferent ? FontWeight.bold : null,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
