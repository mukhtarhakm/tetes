import 'package:flutter/material.dart';

import '../../core/ui/app_bottom_nav.dart';
import '../../core/ui/state_views.dart';
import '../router/app_routes.dart';
import '../theme/tokens.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _navigationItems = [
    AppBottomNavItem(label: 'Seduh', icon: Icons.coffee_rounded),
    AppBottomNavItem(label: 'Jurnal', icon: Icons.menu_book_outlined),
    AppBottomNavItem(label: 'Eksplor', icon: Icons.explore_outlined),
    AppBottomNavItem(label: 'Profil', icon: Icons.person_outline_rounded),
  ];

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _TabEmptyView(
            title: 'Seduh',
            message: 'Belum ada seduhan. Alat bantu seduh akan hadir di sini.',
            icon: Icons.coffee_rounded,
            // Sementara untuk menguji rute layar contoh Langkah 2.
            actionLabel: 'Lihat komponen dasar',
            onActionPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.foundationPreview);
            },
          ),
          const _TabEmptyView(
            title: 'Jurnal',
            message: 'Riwayat seduhanmu akan muncul di sini.',
            icon: Icons.menu_book_outlined,
          ),
          const _TabEmptyView(
            title: 'Eksplor',
            message: 'Agenda, toko, kurs, dan game akan hadir di sini.',
            icon: Icons.explore_outlined,
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
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _TabEmptyView extends StatelessWidget {
  const _TabEmptyView({
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onActionPressed,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

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
          actionLabel: actionLabel,
          onActionPressed: onActionPressed,
        ),
      ),
    );
  }
}
