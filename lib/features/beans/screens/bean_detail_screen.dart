import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/format_ratio.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_dialog.dart';
import '../../../core/ui/score_chart.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/utils/display_format.dart';
import '../../journal/journal_model.dart';
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
        _BeanSummaryCard(bean: bean),
        const SizedBox(height: AppSpacing.s16),
        if (_hasPrice(bean)) ...[
          _PriceCard(bean: bean),
          const SizedBox(height: AppSpacing.s16),
        ],
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
        _BestSettingCard(bean: bean),
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
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: AppSpacing.s16),
              ref
                  .watch(beanActiveBrewsProvider(bean.id))
                  .when(
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
        _HistoryCard(bean: bean),
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

bool _hasPrice(Bean bean) =>
    bean.priceOriginal != null || bean.priceIdrPerKg != null;

({String label, StatusPillVariant variant}) _stockStatus(Bean bean) {
  if (bean.remainingStockG <= 0) {
    return (label: 'Habis', variant: StatusPillVariant.error);
  }
  if (bean.isLowStock) {
    return (label: 'Menipis', variant: StatusPillVariant.warning);
  }
  return (label: 'Stok aman', variant: StatusPillVariant.synced);
}

class _BeanSummaryCard extends StatelessWidget {
  const _BeanSummaryCard({required this.bean});

  final Bean bean;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = _stockStatus(bean);
    final remaining = bean.remainingStockG < 0 ? 0.0 : bean.remainingStockG;
    final fraction = bean.initialStockG <= 0
        ? 0.0
        : (remaining / bean.initialStockG).clamp(0.0, 1.0);
    final barColor = switch (status.variant) {
      StatusPillVariant.error => AppColors.error,
      StatusPillVariant.warning => AppColors.warning,
      _ => AppColors.primary,
    };
    final subtitle = [
      bean.roastery,
      bean.beanType?.label,
    ].whereType<String>().where((item) => item.isNotEmpty).join(' · ');
    final info = <(String, String)>[
      if (bean.origin != null && bean.origin!.isNotEmpty)
        ('Asal', bean.origin!),
      if (_processLabel(bean) != null) ('Proses', _processLabel(bean)!),
      ('Sumber', bean.isSelfRoasted ? 'Roasting sendiri' : 'Dibeli'),
      if (bean.species == BeanSpecies.campuran && bean.arabicaPercent != null)
        ('Arabika', '${bean.arabicaPercent}%'),
      if (bean.roastDate != null && bean.roastDate!.isNotEmpty)
        ('Tanggal roasting', _formatDate(bean.roastDate!)),
      if (bean.packSizeG != null)
        ('Ukuran kemasan', '${formatNumber(bean.packSizeG!)} g'),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bean.name, style: textTheme.headlineLarge),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              StatusPill(label: status.label, variant: status.variant),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              AppChip(label: bean.species.label),
              if (bean.roastLevel != null)
                AppChip(label: bean.roastLevel!.label),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.innerCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${formatNumber(remaining)} g',
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        'tersisa',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                    Text(
                      'dari ${formatNumber(bean.initialStockG)} g',
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: AppSizes.stockBarHeight,
                    color: barColor,
                    backgroundColor: AppColors.divider,
                  ),
                ),
              ],
            ),
          ),
          if (info.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s16),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - AppSpacing.s16) / 2;
                return Wrap(
                  spacing: AppSpacing.s16,
                  runSpacing: AppSpacing.s16,
                  children: [
                    for (final item in info)
                      SizedBox(
                        width: width,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$1,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppColors.inkSoft,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              item.$2,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceCard extends StatefulWidget {
  const _PriceCard({required this.bean});

  final Bean bean;

  @override
  State<_PriceCard> createState() => _PriceCardState();
}

class _PriceCardState extends State<_PriceCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final bean = widget.bean;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppColors.inkSoft);
    final packageIdr = _packagePriceIdr(bean);
    final original = bean.priceOriginal == null
        ? null
        : '${formatNumber(bean.priceOriginal!)} ${bean.currency ?? ''}'.trim();
    final headline = packageIdr ?? original ?? formatIdr(bean.priceIdrPerKg!);
    final subtitleParts = [
      if (bean.packSizeG != null && (packageIdr ?? original) != null)
        'per kemasan ${formatNumber(bean.packSizeG!)} g',
      if (bean.priceIdrPerKg != null)
        '${formatIdr(bean.priceIdrPerKg!)} per kg',
    ];
    final details = <(String, String)>[
      if (original != null) ('Harga kemasan', original),
      if (_fxLabel(bean) != null) ('Kurs saat input', _fxLabel(bean)!),
      if (packageIdr != null) ('Harga rupiah per kemasan', packageIdr),
      if (bean.priceIdrPerKg != null)
        ('Harga rupiah per kg', formatIdr(bean.priceIdrPerKg!)),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: AppSizes.settingsIconCircle,
                height: AppSizes.settingsIconCircle,
                decoration: const BoxDecoration(
                  color: AppColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.payments_outlined),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: textTheme.titleLarge),
                    if (subtitleParts.isNotEmpty)
                      Text(subtitleParts.join(' · '), style: muted),
                  ],
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Semantics(
              button: true,
              expanded: _expanded,
              label: 'Rincian harga dan kurs',
              child: InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppSizes.minimumTouchTarget,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Rincian harga dan kurs',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.inkSoft,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_expanded)
              for (final item in details)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(item.$1, style: muted)),
                      const SizedBox(width: AppSpacing.s16),
                      Expanded(
                        child: Text(
                          item.$2,
                          style: textTheme.bodyMedium,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _BestSettingCard extends StatelessWidget {
  const _BestSettingCard({required this.bean});

  final Bean bean;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasBest =
        bean.bestBrewRatio != null &&
        bean.bestBrewWaterTempC != null &&
        bean.bestBrewTasteScore != null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pengaturan terbaik', style: textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s12),
          if (hasBest)
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.innerCard),
              ),
              child: Row(
                children: [
                  _BestStat(
                    label: 'Rasio',
                    child: Text(
                      formatRatio(bean.bestBrewRatio!),
                      style: textTheme.titleLarge,
                    ),
                  ),
                  const _BestDivider(),
                  _BestStat(
                    label: 'Suhu air',
                    child: Text(
                      '${bean.bestBrewWaterTempC}°C',
                      style: textTheme.titleLarge,
                    ),
                  ),
                  const _BestDivider(),
                  _BestStat(
                    label: 'Skor rasa',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${bean.bestBrewTasteScore}',
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.rating,
                          size: AppSpacing.s20,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              bean.brewCount == 0
                  ? 'Belum ada seduhan untuk biji ini.'
                  : 'Belum ada pengaturan seduh terbaik.',
              style: textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
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
    );
  }
}

class _BestStat extends StatelessWidget {
  const _BestStat({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _BestDivider extends StatelessWidget {
  const _BestDivider();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: AppSizes.settingsIconCircle,
    child: VerticalDivider(
      width: AppSizes.dividerThickness,
      thickness: AppSizes.dividerThickness,
      color: AppColors.divider,
    ),
  );
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.bean});

  final Bean bean;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final history = ref.watch(beanHistoryBrewsProvider(bean.id));
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s20,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Riwayat seduhan', style: textTheme.titleLarge),
                history.maybeWhen(
                  data: (brews) {
                    final active = brews.where((b) => !b.isCancelled).length;
                    return brews.isEmpty
                        ? const SizedBox.shrink()
                        : Text(
                            '$active seduhan aktif',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.inkSoft,
                            ),
                          );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          history.when(
            data: (brews) {
              if (brews.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  child: Text(
                    'Belum ada seduhan untuk biji ini.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (var index = 0; index < brews.length; index++) ...[
                    if (index > 0)
                      const Divider(
                        height: AppSizes.dividerThickness,
                        color: AppColors.divider,
                        indent: AppSizes.historyBadge + AppSpacing.s16,
                      ),
                    _HistoryRow(
                      item: brews[index],
                      isBest: brews[index].isBestBrew,
                    ),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.s16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.all(AppSpacing.s12),
              child: Text('Gagal memuat riwayat seduhan.'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item, required this.isBest});

  final BrewJournalItem item;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final badgeColor = item.isCancelled
        ? AppColors.background
        : switch (item.tasteScore) {
            <= 2 => AppColors.stage4Soft,
            3 => AppColors.stage3Soft,
            _ => AppColors.stage2Soft,
          };
    return Semantics(
      button: true,
      label:
          'Seduhan ${_formatDate(item.brewedAtUtc)}, skor ${item.tasteScore} dari 5',
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => BrewDetailScreen(brewId: item.id)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.historyRowHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Row(
              children: [
                Container(
                  width: AppSizes.historyBadge,
                  height: AppSizes.historyBadge,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${item.tasteScore}',
                    style: textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: AppSpacing.s8,
                        runSpacing: AppSpacing.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            _formatDate(item.brewedAtUtc),
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isBest && !item.isCancelled)
                            const StatusPill(
                              label: 'Terbaik',
                              variant: StatusPillVariant.warning,
                            ),
                          if (item.isCancelled)
                            const StatusPill(
                              label: 'Dibatalkan',
                              variant: StatusPillVariant.pending,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        '${formatNumber(item.doseG)} g · '
                        '${formatRatio(item.ratio)} · ${item.waterTempC}°C',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
