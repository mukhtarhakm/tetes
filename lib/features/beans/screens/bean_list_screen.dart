import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/ui/rating_stars.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/utils/format_ratio.dart';
import '../bean_model.dart';
import '../state/bean_providers.dart';
import 'bean_detail_screen.dart';
import 'bean_form_screen.dart';

enum _BeanFilter { all, lowStock, selfRoasted }

class BeanListScreen extends ConsumerStatefulWidget {
  const BeanListScreen({super.key});

  @override
  ConsumerState<BeanListScreen> createState() => _BeanListScreenState();
}

class _BeanListScreenState extends ConsumerState<BeanListScreen> {
  final _search = TextEditingController();
  String _query = '';
  _BeanFilter _filter = _BeanFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Bean> _visible(List<Bean> items) {
    final query = _query.trim().toLowerCase();
    return items.where((bean) {
      final matchesFilter = switch (_filter) {
        _BeanFilter.all => true,
        _BeanFilter.lowStock => bean.isLowStock || bean.remainingStockG <= 0,
        _BeanFilter.selfRoasted => bean.isSelfRoasted,
      };
      if (!matchesFilter) return false;
      if (query.isEmpty) return true;
      return [
        bean.name,
        bean.roastery,
        bean.origin,
      ].whereType<String>().any((text) => text.toLowerCase().contains(query));
    }).toList();
  }

  Widget _header(BuildContext context, int count) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          controller: _search,
          isSearch: true,
          hintText: 'Cari nama, roastery, asal...',
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
        ),
        const SizedBox(height: AppSpacing.s12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (filter, label) in const [
                (_BeanFilter.all, 'Semua'),
                (_BeanFilter.lowStock, 'Stok menipis'),
                (_BeanFilter.selfRoasted, 'Roasting sendiri'),
              ]) ...[
                AppChip(
                  label: label,
                  selected: _filter == filter,
                  onSelected: (_) => setState(() => _filter = filter),
                ),
                const SizedBox(width: AppSpacing.s8),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(
          count == 0 ? 'Tidak ada biji yang cocok.' : '$count biji',
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final beans = ref.watch(beanListProvider);
    final archived = ref.watch(archivedBeanListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Tambah biji',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        bottom: false,
        child: beans.when(
          loading: () => const LoadingView(message: 'Memuat biji...'),
          error: (_, _) => ErrorView(
            message: 'Daftar biji tidak dapat dimuat.',
            onRetry: () => ref.invalidate(beanListProvider),
          ),
          data: (items) => archived.when(
            loading: () => const LoadingView(message: 'Memuat biji...'),
            error: (_, _) => ErrorView(
              message: 'Daftar biji tidak dapat dimuat.',
              onRetry: () => ref.invalidate(archivedBeanListProvider),
            ),
            data: (archivedItems) => items.isEmpty && archivedItems.isEmpty
                ? EmptyView(
                    title: 'Belum ada biji',
                    message:
                        'Tambahkan biji pertama untuk mulai mencatat stok dan profilnya.',
                    icon: Icons.coffee_outlined,
                    actionLabel: 'Tambah biji',
                    onActionPressed: () => _openForm(context),
                  )
                : _buildList(context, _visible(items), archivedItems),
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Bean> items,
    List<Bean> archivedItems,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(beanListProvider);
        ref.invalidate(archivedBeanListProvider);
        await ref.read(beanListProvider.future);
        await ref.read(archivedBeanListProvider.future);
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          AppSpacing.s16,
          AppSpacing.s20,
          AppSizes.floatingButtonClearance,
        ),
        itemCount: items.length + 1 + (archivedItems.isEmpty ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s16),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _header(context, items.length);
          }
          if (index == items.length + 1) {
            return ExpansionTile(
              key: const Key('archived-beans-section'),
              title: Text('Biji diarsipkan (${archivedItems.length})'),
              children: archivedItems
                  .map(
                    (bean) => AppCard(
                      child: ListTile(
                        title: Text(bean.name),
                        subtitle: Text(bean.roastery ?? 'Roastery belum diisi'),
                        trailing: TextButton(
                          onPressed: () async {
                            final restored = await ref
                                .read(beanMutationProvider.notifier)
                                .restore(bean.id);
                            if (restored && context.mounted) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text('Biji dipulihkan.'),
                                  ),
                                );
                            }
                          },
                          child: const Text('Pulihkan'),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            );
          }
          final bean = items[index - 1];
          return BeanCard(
            bean: bean,
            onTap: () => _openDetail(context, bean.id),
          );
        },
      ),
    );
  }

  Future<void> _openForm(BuildContext context) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const BeanFormScreen()));
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Biji berhasil disimpan.')),
        );
    }
  }

  Future<void> _openDetail(BuildContext context, String beanId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => BeanDetailScreen(beanId: beanId)),
    );
  }
}

class BeanCard extends StatelessWidget {
  const BeanCard({required this.bean, required this.onTap, super.key});

  final Bean bean;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final roastAge = _roastAgeLabel(bean.roastDate);
    final origin = bean.roastery ?? 'Roastery belum diisi';
    final stock = bean.remainingStockG < 0 ? 0.0 : bean.remainingStockG;
    final isEmpty = stock <= 0;
    final pillLabel = isEmpty
        ? 'Habis'
        : bean.isLowStock
        ? 'Menipis'
        : 'Stok aman';
    final pillVariant = isEmpty
        ? StatusPillVariant.error
        : bean.isLowStock
        ? StatusPillVariant.warning
        : StatusPillVariant.synced;
    final hasBest =
        bean.bestBrewRatio != null &&
        bean.bestBrewWaterTempC != null &&
        bean.bestBrewTasteScore != null;

    return Semantics(
      button: true,
      label: 'Lihat detail ${bean.name}',
      child: GestureDetector(
        onTap: onTap,
        child: AppCard(
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
                        Text(bean.name, style: textTheme.titleLarge),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          roastAge == null ? origin : '$origin · $roastAge',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  StatusPill(label: pillLabel, variant: pillVariant),
                  const SizedBox(width: AppSpacing.s4),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  AppChip(label: bean.species.label),
                  if (bean.roastLevel != null)
                    AppChip(label: bean.roastLevel!.label),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${_formatNumber(stock)} g',
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    'tersisa',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
              if (hasBest) ...[
                const SizedBox(height: AppSpacing.s12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Terbaik',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                      Text(
                        '${formatRatio(bean.bestBrewRatio!)} · '
                        '${bean.bestBrewWaterTempC}°C',
                        style: textTheme.bodyMedium,
                      ),
                      RatingStars(
                        score: bean.bestBrewTasteScore!,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ] else if (bean.bestBrewId == null) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Belum ada pengaturan seduh terbaik.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String? _roastAgeLabel(String? roastDate) {
  if (roastDate == null) {
    return null;
  }
  final date = DateTime.tryParse(roastDate);
  if (date == null) {
    return null;
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final age = today.difference(date).inDays;
  return age < 0 ? 'Tanggal roasting mendatang' : '$age hari sejak roasting';
}
