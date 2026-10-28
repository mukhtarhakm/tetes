import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../app/theme/tokens.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/bean_icon.dart';
import '../../core/ui/rating_stars.dart';
import '../../core/ui/state_views.dart';
import '../../core/ui/status_pill.dart';
import '../../core/utils/event_display.dart';
import '../../core/utils/event_time.dart';
import '../../core/utils/format_ratio.dart';
import '../../data/sync/sync_service.dart';
import '../auth/state/auth_providers.dart';
import '../auth/state/session_controller.dart';
import '../beans/bean_model.dart';
import '../beans/screens/bean_form_screen.dart';
import '../beans/screens/bean_list_screen.dart';
import '../beans/state/bean_providers.dart';
import '../brew/brew_plan.dart';
import '../brew/screens/brew_setup_screen.dart';
import '../brew/state/brew_setup_controller.dart';
import '../chat/screens/chat_screen.dart';
import '../explore/currency_calculator_screen.dart';
import '../explore/event_model.dart';
import '../explore/explore_screen.dart';
import '../explore/store_screen.dart';
import '../game/game_prototype_screen.dart';
import '../journal/journal_model.dart';
import '../journal/screens/brew_detail_screen.dart';
import '../journal/screens/journal_screen.dart';
import '../journal/state/journal_controller.dart';
import '../profile/profile_photo_service.dart';

class HomeIdentity {
  const HomeIdentity(this.username, this.photo);
  final String username;
  final File? photo;
}

class HomeData {
  const HomeData({
    required this.beans,
    required this.latestBrew,
    required this.nextEvent,
    required this.againPlan,
    this.againScore,
    this.againIsBest = true,
  });
  final List<Bean> beans;
  final BrewJournalItem? latestBrew;
  final EventItem? nextEvent;
  final BrewPlan? againPlan;
  // Skor dari seduhan yang menjadi sumber againPlan.
  final int? againScore;
  // False bila againPlan diambil dari seduhan terakhir karena biji itu
  // belum punya seduhan terbaik.
  final bool againIsBest;
  int get lowStockCount => beans.where((bean) => bean.isLowStock).length;
}

final homeIdentityProvider = FutureProvider<HomeIdentity>((ref) async {
  final userId = (await ref.watch(sessionControllerProvider.future)).userId;
  if (userId == null) throw StateError('Sesi tidak tersedia.');
  final profile = await (await ref.watch(
    userRepositoryProvider.future,
  )).profile(userId);
  final username = (profile?['username'] as String?)?.trim();
  final photoName = profile?['photo_path'] as String?;
  File? photo;
  if (photoName != null) {
    try {
      final directory = await ProfilePhotoService().directory();
      final candidate = File(
        path.join(directory.path, path.basename(photoName)),
      );
      if (await candidate.exists()) photo = candidate;
    } catch (_) {
      // Inisial tetap tersedia jika foto lokal tidak dapat dibaca.
    }
  }
  return HomeIdentity(
    username == null || username.isEmpty ? 'Barista' : username,
    photo,
  );
});

final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final userId = (await ref.watch(sessionControllerProvider.future)).userId;
  if (userId == null) throw StateError('Sesi tidak tersedia.');
  final beans = await ref.watch(beanListProvider.future);
  final brews = await (await ref.watch(
    brewRepositoryProvider.future,
  )).findJournalBrews(userId: userId, limit: 1);
  final events = await (await ref.watch(
    eventRepositoryProvider.future,
  )).listActive(userId);
  final now = DateTime.now().toUtc();
  EventItem? nextEvent;
  for (final event in events) {
    if (!event.startUtc.isBefore(now)) {
      nextEvent = event;
      break;
    }
  }
  // Pintasan "Seduh lagi" memakai pengaturan terbaik dari biji yang terakhir
  // diseduh, bukan seduhan terakhir itu sendiri (yang bisa saja berskor 1).
  BrewPlan? plan;
  int? againScore;
  var againIsBest = true;
  final repo = await ref.read(brewRepositoryProvider.future);
  Bean? latestBean;
  if (brews.isNotEmpty) {
    for (final bean in beans) {
      if (bean.id == brews.first.beanId) latestBean = bean;
    }
  }
  final latestBest = latestBean?.bestBrewId;
  if (latestBean != null && latestBest != null) {
    plan = await repo.findBestPlan(
      userId: userId,
      beanId: latestBean.id,
      bestBrewId: latestBest,
    );
    againScore = latestBean.bestBrewTasteScore;
  }
  if (plan == null && latestBean != null) {
    final detail = await repo.findBrewDetail(
      userId: userId,
      brewId: brews.first.id,
    );
    plan = detail?.toBrewPlan();
    againScore = brews.first.tasteScore;
    againIsBest = false;
  }
  if (plan == null) {
    againIsBest = true;
    for (final bean in beans) {
      if (bean.bestBrewId == null) continue;
      plan = await repo.findBestPlan(
        userId: userId,
        beanId: bean.id,
        bestBrewId: bean.bestBrewId!,
      );
      if (plan != null) {
        againScore = bean.bestBrewTasteScore;
        break;
      }
    }
  }
  return HomeData(
    beans: beans,
    latestBrew: brews.isEmpty ? null : brews.first,
    nextEvent: nextEvent,
    againPlan: plan,
    againScore: againScore,
    againIsBest: againIsBest,
  );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    required this.syncStatus,
    required this.syncLoading,
    required this.syncError,
    required this.onOpenSync,
    super.key,
  });

  final SyncStatus? syncStatus;
  final bool syncLoading;
  final String? syncError;
  final VoidCallback onOpenSync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(homeDataProvider);
    final identity = ref.watch(homeIdentityProvider).asData?.value;
    final now = DateTime.now();
    return SafeArea(
      bottom: false,
      child: data.when(
        loading: () => ListView(
          padding: AppInsets.screen,
          children: const [
            AppCard(child: Text('Memuat Beranda...')),
            SizedBox(height: AppSpacing.s16),
            AppCard(child: Text('Memuat ringkasan...')),
          ],
        ),
        error: (_, _) => Padding(
          padding: AppInsets.screen,
          child: ErrorView(
            message: 'Beranda belum dapat dimuat. Coba lagi.',
            onRetry: () => ref.invalidate(homeDataProvider),
          ),
        ),
        data: (home) => ListView(
          padding: AppInsets.screen,
          children: [
            Text(
              EventDisplay.date(now),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: AppSpacing.s4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${greetingForHour(now.hour)},',
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                      Text(
                        (identity?.username ?? 'Barista').replaceAll(
                          '_',
                          '_\u200B',
                        ),
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                InkWell(
                  onTap: onOpenSync,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: StatusPill(
                    label:
                        syncError != null || (syncStatus?.errorCount ?? 0) > 0
                        ? 'Gagal'
                        : syncLoading ||
                              syncStatus == null ||
                              (syncStatus?.pendingCount ?? 0) > 0
                        ? 'Menunggu sync'
                        : 'Tersinkron',
                    variant:
                        syncError != null || (syncStatus?.errorCount ?? 0) > 0
                        ? StatusPillVariant.error
                        : (syncStatus?.pendingCount ?? 0) > 0 ||
                              syncLoading ||
                              syncStatus == null
                        ? StatusPillVariant.pending
                        : StatusPillVariant.synced,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (home.beans.isEmpty)
                    _EmptyBrewCard(
                      onAddBean: () =>
                          _openAndRefresh(context, ref, const BeanFormScreen()),
                    )
                  else ...[
                    SizedBox(
                      height: AppSizes.stateIconContainer,
                      child: AppButton(
                        label: 'Mulai seduh',
                        icon: Icons.play_arrow_rounded,
                        onPressed: () =>
                            _open(context, const BrewSetupScreen()),
                      ),
                    ),
                    if (home.againPlan case final plan?) ...[
                      const SizedBox(height: AppSpacing.s16),
                      _BrewAgainRow(
                        beanName: _beanName(home.beans, plan.beanId),
                        ratio: formatRatio(plan.ratio),
                        waterTempC: plan.waterTempC,
                        isBest: home.againIsBest,
                        score:
                            home.againScore ??
                            (home.latestBrew?.beanId == plan.beanId
                                ? home.latestBrew?.tasteScore
                                : home.beans
                                      .where((bean) => bean.id == plan.beanId)
                                      .first
                                      .bestBrewTasteScore),
                        onTap: () =>
                            _open(context, BrewSetupScreen(initialPlan: plan)),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            Text('Ringkasan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s12),
            AppCard(
              child: InkWell(
                onTap: home.latestBrew == null
                    ? null
                    : () => _open(
                        context,
                        BrewDetailScreen(brewId: home.latestBrew!.id),
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seduhan terakhir',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    if (home.latestBrew case final brew?) ...[
                      Text(
                        brew.beanName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Wrap(
                        spacing: AppSpacing.s8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          RatingStars(score: brew.tasteScore),
                          Text(
                            '· ${_ago(brew.brewedAtUtc, now)}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.inkSoft),
                          ),
                        ],
                      ),
                    ] else
                      const Text('Belum ada seduhan. Mulai seduh pertamamu!'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Stok menipis',
                      child: home.lowStockCount == 0
                          ? const Text('Semua stok aman')
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${home.lowStockCount} biji',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineLarge,
                                ),
                                const SizedBox(height: AppSpacing.s8),
                                Text(
                                  '${home.beans.firstWhere((bean) => bean.isLowStock).name} · sisa ${home.beans.firstWhere((bean) => bean.isLowStock).remainingStockG.toStringAsFixed(0)} g',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                      onTap: () =>
                          _openAndRefresh(context, ref, const _BeanPage()),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Event berikutnya',
                      child: home.nextEvent == null
                          ? const Text('Belum ada event')
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  home.nextEvent!.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: AppSpacing.s4),
                                Text(
                                  '${EventDisplay.countdown(home.nextEvent!.startUtc, now)} · ${EventDisplay.clock(EventTime.fromUtc(home.nextEvent!.startUtc, EventTime.zones['WIB']!))} WIB',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                      onTap: () => _openAndRefresh(
                        context,
                        ref,
                        const EventAgendaScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
            _ShortcutSection(
              shortcuts: [
                _Shortcut(
                  'Tanya Barista',
                  'Chat soal seduhanmu',
                  const Icon(Icons.chat_bubble_outline, color: AppColors.ink),
                  AppColors.accent,
                  () => _open(context, const ChatScreen()),
                ),
                _Shortcut(
                  'Jurnal',
                  'Riwayat & bandingkan',
                  const Icon(Icons.menu_book_outlined, color: AppColors.ink),
                  AppColors.primaryContainer,
                  () => _openAndRefresh(context, ref, const JournalScreen()),
                ),
                _Shortcut(
                  'Biji kopi',
                  'Stok & profil biji',
                  const BeanIcon(),
                  AppColors.primaryContainer,
                  () => _openAndRefresh(context, ref, const _BeanPage()),
                ),
                _Shortcut(
                  'Toko Terdekat',
                  'Peta & rute',
                  const Icon(Icons.location_on_outlined, color: AppColors.ink),
                  AppColors.accent,
                  () => _open(context, const StoreScreen()),
                ),
                _Shortcut(
                  'Agenda Event',
                  'WIB, WITA, WIT, London',
                  const Icon(Icons.event_outlined, color: AppColors.ink),
                  AppColors.accent,
                  () =>
                      _openAndRefresh(context, ref, const EventAgendaScreen()),
                ),
                _Shortcut(
                  'Cek Harga Biji',
                  'USD, EUR, JPY ke rupiah',
                  const Icon(
                    Icons.currency_exchange_outlined,
                    color: AppColors.ink,
                  ),
                  AppColors.accent,
                  () => _open(context, const CurrencyCalculatorScreen()),
                ),
                _Shortcut(
                  'Steady Pour',
                  'Mini game gyroscope',
                  const Icon(
                    Icons.sports_esports_outlined,
                    color: AppColors.ink,
                  ),
                  AppColors.primaryContainer,
                  () => _open(context, const GamePrototypeScreen()),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),
          ],
        ),
      ),
    );
  }

  static String greetingForHour(int hour) => hour < 5
      ? 'Selamat malam'
      : hour < 11
      ? 'Selamat pagi'
      : hour < 15
      ? 'Selamat siang'
      : hour < 18
      ? 'Selamat sore'
      : 'Selamat malam';
  static String _beanName(List<Bean> beans, String id) =>
      beans.where((bean) => bean.id == id).first.name;
  static String _ago(String utc, DateTime now) {
    final age = now.difference(DateTime.parse(utc).toLocal());
    if (age.inMinutes < 60) return '${age.inMinutes} menit lalu';
    if (age.inHours < 24) return '${age.inHours} jam lalu';
    return '${age.inDays} hari lalu';
  }

  static Future<void> _open(BuildContext context, Widget page) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  static Future<void> _openAndRefresh(
    BuildContext context,
    WidgetRef ref,
    Widget page,
  ) async {
    await _open(context, page);
    if (page is JournalScreen) {
      ref.read(journalSelectionProvider.notifier).reset();
    }
    ref.invalidate(homeDataProvider);
  }
}

class _BeanPage extends StatelessWidget {
  const _BeanPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Biji kopi')),
    body: const BeanListScreen(),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.child, this.onTap});
  final String title;
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: AppInsets.mapListCard,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.s8),
          child,
        ],
      ),
    ),
  );
}

class _EmptyBrewCard extends StatelessWidget {
  const _EmptyBrewCard({required this.onAddBean});
  final VoidCallback onAddBean;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: AppSizes.navigationIcon,
            backgroundColor: AppColors.primaryContainer,
            child: BeanIcon(),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tambah biji pertamamu',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Catat biji dulu, lalu mulai seduh V60 dengan panduan.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.s16),
      SizedBox(
        height: AppSizes.stateIconContainer,
        child: AppButton(
          label: 'Tambah biji',
          icon: Icons.add_rounded,
          onPressed: onAddBean,
        ),
      ),
    ],
  );
}

class _BrewAgainRow extends StatelessWidget {
  const _BrewAgainRow({
    required this.beanName,
    required this.ratio,
    required this.waterTempC,
    required this.score,
    required this.onTap,
    this.isBest = true,
  });
  final bool isBest;
  final String beanName;
  final String ratio;
  final int waterTempC;
  final int? score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.background,
    borderRadius: BorderRadius.circular(AppRadius.innerCard),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.innerCard),
      child: Padding(
        padding: AppInsets.mapListCard,
        child: Row(
          children: [
            const CircleAvatar(
              radius: AppSizes.navigationIcon,
              backgroundColor: AppColors.primaryContainer,
              child: BeanIcon(),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBest
                        ? 'Seduh lagi, pengaturan terbaik'
                        : 'Seduh lagi, seduhan terakhir',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                  Text(
                    beanName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Wrap(
                    spacing: AppSpacing.s8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '$ratio · $waterTempC°C',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                      if (score != null)
                        RatingStars(score: score!, compact: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
          ],
        ),
      ),
    ),
  );
}

class _Shortcut {
  const _Shortcut(
    this.title,
    this.description,
    this.icon,
    this.color,
    this.onTap,
  );
  final String title;
  final String description;
  final Widget icon;
  final Color color;
  final VoidCallback onTap;
}

class _ShortcutSection extends StatelessWidget {
  const _ShortcutSection({required this.shortcuts});
  final List<_Shortcut> shortcuts;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Pintasan', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.s12),
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s12,
          children: [
            for (final shortcut in shortcuts)
              SizedBox(
                width: (constraints.maxWidth - AppSpacing.s12) / 2,
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  child: InkWell(
                    onTap: shortcut.onTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: AppSizes.navigationIcon,
                          backgroundColor: shortcut.color,
                          child: shortcut.icon,
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          shortcut.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          shortcut.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}
