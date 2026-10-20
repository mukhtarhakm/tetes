import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/app_bottom_nav.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_dialog.dart';
import '../../core/ui/state_views.dart';
import '../../core/ui/status_pill.dart';
import '../../data/db/database_provider.dart';
import '../../data/remote/sync_client.dart';
import '../../data/repositories/brew_repo.dart';
import '../../data/sync/sync_service.dart';
import '../../features/auth/session/force_logout.dart';
import '../../features/auth/state/auth_providers.dart';
import '../../features/auth/state/session_controller.dart';
import '../../features/beans/screens/bean_list_screen.dart';
import '../../features/beans/state/bean_providers.dart';
import '../../features/journal/screens/journal_screen.dart';
import '../../features/journal/state/journal_controller.dart';
import '../router/app_routes.dart';
import '../theme/tokens.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  static const _navigationItems = [
    AppBottomNavItem(label: 'Seduh', icon: Icons.coffee_rounded),
    AppBottomNavItem(label: 'Jurnal', icon: Icons.menu_book_outlined),
    AppBottomNavItem(label: 'Eksplor', icon: Icons.explore_outlined),
    AppBottomNavItem(label: 'Saran & Kesan', icon: Icons.rate_review_outlined),
    AppBottomNavItem(label: 'Profil', icon: Icons.person_outline_rounded),
    AppBottomNavItem(label: 'Logout', icon: Icons.logout_rounded),
  ];

  static const _logoutIndex = 5;

  int _currentIndex = 0;
  bool _logoutFlowActive = false;
  bool _journalVisited = false;
  StreamSubscription<String>? _brewChanges;
  Future<SyncService>? _syncService;
  SyncStatus? _syncStatus;
  String? _syncError;
  bool _syncLoading = true;

  @override
  void initState() {
    super.initState();
    _brewChanges = BrewRepository.changes.listen((userId) {
      if (userId == ref.read(sessionControllerProvider).asData?.value.userId) {
        unawaited(_automaticSync());
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_syncAfterInitialLoad());
    });
  }

  @override
  void dispose() {
    _brewChanges?.cancel();
    _syncService?.then((service) => service.close());
    super.dispose();
  }

  Future<SyncService> _service() {
    return _syncService ??= _createService();
  }

  Future<void> _syncAfterInitialLoad() async {
    try {
      await ref.read(beanListProvider.future);
    } catch (_) {
      // Sinkronisasi tetap dapat berjalan bila daftar biji gagal dimuat.
    }
    if (mounted) await _automaticSync();
  }

  Future<SyncService> _createService() async {
    final database = await ref.read(databaseProvider.future);
    return SyncService(
      database,
      SyncClient(sessionStorage: ref.read(sessionStorageProvider)),
      () => forceLogoutOnUnauthorized(
        ref.read(sessionControllerProvider.notifier),
      ),
    );
  }

  Future<void> _automaticSync() async {
    final userId = ref.read(sessionControllerProvider).asData?.value.userId;
    if (userId == null) return;
    try {
      final service = await _service();
      await service.run(userId: userId);
    } catch (_) {
      // Sinkronisasi otomatis tetap senyap; baris gagal tidak berubah.
    } finally {
      try {
        final status = await (await _service()).status(userId);
        if (mounted) {
          setState(() {
            _syncStatus = status;
            _syncLoading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _syncLoading = false;
          });
        }
      }
    }
  }

  Future<void> _manualSync() async {
    final userId = ref.read(sessionControllerProvider).asData?.value.userId;
    if (userId == null) {
      setState(() {
        _syncError = 'Sesi tidak tersedia. Masuk kembali.';
        _syncLoading = false;
      });
      return;
    }
    setState(() {
      _syncLoading = true;
      _syncError = null;
    });
    try {
      final status = await (await _service()).run(
        userId: userId,
        retryErrors: true,
      );
      if (!mounted) {
        return;
      }
      final reasons = status.summary?['rejected'];
      final messages = <String>[];
      if (reasons is Map) {
        for (final entry in reasons.entries) {
          if (entry.value is num && (entry.value as num) > 0) {
            messages.add(
              '${entry.value}× ${SyncService.reasonMessages[entry.key] ?? 'Data ditolak.'}',
            );
          }
        }
      }
      setState(() {
        _syncStatus = status;
        _syncError = messages.isEmpty ? null : messages.join(' ');
      });
    } on SyncException catch (error) {
      if (mounted) {
        setState(() {
          _syncError = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _syncError = 'Sinkronisasi gagal. Coba lagi.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const BeanListScreen(),
          _journalVisited ? const JournalScreen() : const SizedBox.shrink(),
          const _TabEmptyView(
            title: 'Eksplor',
            message: 'Agenda, toko, kurs, dan game akan hadir di sini.',
            icon: Icons.explore_outlined,
          ),
          const _TabEmptyView(
            title: 'Saran & Kesan',
            message: 'Saran dan kesanmu akan dapat dikirim dari sini.',
            icon: Icons.rate_review_outlined,
          ),
          _SyncProfile(
            status: _syncStatus,
            error: _syncError,
            loading: _syncLoading,
            onSync: _manualSync,
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        items: _navigationItems,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index == _logoutIndex) {
            unawaited(_handleLogoutTap());
            return;
          }

          setState(() {
            _currentIndex = index;
            if (index == 1) {
              _journalVisited = true;
            } else {
              ref.read(journalSelectionProvider.notifier).reset();
            }
          });
        },
      ),
    );
  }

  Future<void> _handleLogoutTap() async {
    if (_logoutFlowActive) {
      return;
    }
    setState(() {
      _logoutFlowActive = true;
    });

    try {
      final session = ref.read(sessionControllerProvider).asData?.value;
      final userId = session?.userId;
      if (userId == null) {
        throw StateError('Session pengguna tidak tersedia.');
      }

      final repository = await ref.read(userRepositoryProvider.future);
      final pendingCount = await repository.countPendingSyncData(userId);
      if (!mounted) {
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppDialog(
          title: 'Keluar dari Tetes?',
          message: pendingCount > 0
              ? 'Ada $pendingCount data belum tersinkron. Tetap keluar?'
              : 'Kamu yakin ingin keluar dari aplikasi?',
          primaryLabel: 'Keluar',
          onPrimaryPressed: () => Navigator.of(dialogContext).pop(true),
          secondaryLabel: 'Batal',
          onSecondaryPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }

      await ref.read(sessionControllerProvider.notifier).logout();
      AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.home,
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Logout gagal dimulai. Silakan coba lagi.'),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() {
          _logoutFlowActive = false;
        });
      }
    }
  }
}

class _SyncProfile extends StatelessWidget {
  const _SyncProfile({
    required this.status,
    required this.error,
    required this.loading,
    required this.onSync,
  });

  final SyncStatus? status;
  final String? error;
  final bool loading;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final accepted = status?.summary?['accepted'];
    final acceptedCount = accepted is Map
        ? ((accepted['beans'] as num?) ?? 0).toInt() +
              ((accepted['brews'] as num?) ?? 0).toInt()
        : 0;
    final empty =
        status != null &&
        status!.pendingCount == 0 &&
        status!.errorCount == 0 &&
        status!.lastSyncAt == null;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: AppInsets.screen,
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Sinkronisasi',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.s8),
              if (loading)
                const Text('Memuat status sinkronisasi...')
              else if (error != null) ...[
                const StatusPill(
                  label: 'Galat',
                  variant: StatusPillVariant.error,
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(error!),
              ] else if (empty) ...[
                const StatusPill(
                  label: 'Kosong',
                  variant: StatusPillVariant.pending,
                ),
                const SizedBox(height: AppSpacing.s8),
                const Text('Belum ada data yang menunggu sinkronisasi.'),
              ] else if (status != null) ...[
                StatusPill(
                  label: '${status!.pendingCount} data menunggu',
                  variant: status!.errorCount > 0
                      ? StatusPillVariant.error
                      : status!.pendingCount == 0
                      ? StatusPillVariant.synced
                      : StatusPillVariant.pending,
                ),
                const SizedBox(height: AppSpacing.s8),
                if (status!.errorCount > 0)
                  Text('${status!.errorCount} data perlu dicoba ulang.'),
                Text(
                  status!.lastSyncAt == null
                      ? 'Belum pernah sinkron.'
                      : 'Terakhir: ${status!.lastSyncAt}',
                ),
                Text('Hasil terakhir: $acceptedCount diterima.'),
              ] else
                const Text('Status sinkronisasi belum tersedia.'),
              const SizedBox(height: AppSpacing.s8),
              AppButton(
                label: 'Sinkronkan sekarang',
                onPressed: loading ? null : onSync,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabEmptyView extends StatelessWidget {
  const _TabEmptyView({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: AppInsets.screen,
        child: EmptyView(title: title, message: message, icon: icon),
      ),
    );
  }
}
