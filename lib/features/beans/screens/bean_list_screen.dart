import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../bean_model.dart';
import '../state/bean_providers.dart';
import '../../brew/screens/brew_setup_screen.dart';
import 'bean_detail_screen.dart';
import 'bean_form_screen.dart';

class BeanListScreen extends ConsumerWidget {
  const BeanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final beans = ref.watch(beanListProvider);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: AppInsets.screen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Biji kopi', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Kelola profil dan stok biji untuk seduhanmu.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpacing.s20),
            AppButton(
              label: 'Mulai seduh',
              icon: Icons.play_arrow_rounded,
              onPressed: () => _openBrewSetup(context),
            ),
            const SizedBox(height: AppSpacing.s8),
            AppButton(
              label: 'Tambah biji',
              icon: Icons.add_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => _openForm(context),
            ),
            const SizedBox(height: AppSpacing.s20),
            Expanded(
              child: beans.when(
                loading: () => const LoadingView(message: 'Memuat biji...'),
                error: (_, _) => ErrorView(
                  message: 'Daftar biji tidak dapat dimuat.',
                  onRetry: () => ref.invalidate(beanListProvider),
                ),
                data: (items) => items.isEmpty
                    ? EmptyView(
                        title: 'Belum ada biji',
                        message:
                            'Tambahkan biji pertama untuk mulai mencatat stok dan profilnya.',
                        icon: Icons.coffee_outlined,
                        actionLabel: 'Tambah biji',
                        onActionPressed: () => _openForm(context),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(beanListProvider);
                          await ref.read(beanListProvider.future);
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.s16),
                          itemBuilder: (context, index) => _BeanCard(
                            bean: items[index],
                            onTap: () => _openDetail(context, items[index].id),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
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

  Future<void> _openBrewSetup(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const BrewSetupScreen()));
  }

  Future<void> _openDetail(BuildContext context, String beanId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => BeanDetailScreen(beanId: beanId)),
    );
  }
}

class _BeanCard extends StatelessWidget {
  const _BeanCard({required this.bean, required this.onTap});

  final Bean bean;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final roastAge = _roastAgeLabel(bean.roastDate);
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
                        Text(
                          bean.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          bean.roastery ?? 'Roastery belum diisi',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
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
                  StatusPill(
                    label: bean.isLowStock ? 'Stok menipis' : 'Stok aman',
                    variant: bean.isLowStock
                        ? StatusPillVariant.warning
                        : StatusPillVariant.synced,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Sisa ${_formatNumber(bean.remainingStockG)} g'
                '${roastAge == null ? '' : ' • $roastAge'}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                bean.bestBrewId == null
                    ? 'Belum ada pengaturan seduh terbaik.'
                    : 'Pengaturan seduh terbaik tersedia.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
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
