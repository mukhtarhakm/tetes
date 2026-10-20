import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ui/app_bottom_nav.dart';
import '../../core/ui/app_dialog.dart';
import '../../core/ui/state_views.dart';
import '../../features/auth/state/auth_providers.dart';
import '../../features/auth/state/session_controller.dart';
import '../../features/beans/screens/bean_list_screen.dart';
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
          const _TabEmptyView(
            title: 'Profil',
            message: 'Pengaturan dan informasi akun akan muncul di sini.',
            icon: Icons.person_outline_rounded,
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
        child: EmptyView(
          title: title,
          message: message,
          icon: icon,
        ),
      ),
    );
  }
}
