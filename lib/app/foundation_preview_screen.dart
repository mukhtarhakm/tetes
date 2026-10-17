import 'package:flutter/material.dart';

import '../core/ui/app_button.dart';
import '../core/ui/app_card.dart';
import '../core/ui/app_dialog.dart';
import '../core/ui/app_text_field.dart';
import '../core/ui/state_views.dart';
import 'theme/tokens.dart';

class FoundationPreviewScreen extends StatelessWidget {
  const FoundationPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tetes')),
      body: ListView(
        padding: AppInsets.screen,
        children: [
          Text(
            'Fondasi antarmuka',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            'Tema dan komponen dasar siap dipakai oleh layar berikutnya.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: AppSpacing.s24),
          const _SectionTitle('Kartu'),
          const SizedBox(height: AppSpacing.s12),
          const AppCard(
            variant: AppCardVariant.featured,
            child: _CardContent(
              icon: Icons.coffee_rounded,
              title: 'Seduh lebih konsisten',
              message: 'Catat pengaturan terbaik untuk setiap biji.',
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          const AppCard(
            variant: AppCardVariant.tinted,
            child: _CardContent(
              icon: Icons.water_drop_outlined,
              title: 'Aksen Tetes',
              message: 'Cyan dan mint memakai teks hitam agar tetap terbaca.',
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          const _SectionTitle('Kolom isian'),
          const SizedBox(height: AppSpacing.s12),
          const AppTextField(
            label: 'Nama biji',
            hintText: 'Contoh: Gayo Natural',
          ),
          const SizedBox(height: AppSpacing.s16),
          const AppTextField(hintText: 'Cari seduhan', isSearch: true),
          const SizedBox(height: AppSpacing.s24),
          const _SectionTitle('Tombol'),
          const SizedBox(height: AppSpacing.s12),
          AppButton(
            label: 'Tampilkan dialog',
            icon: Icons.open_in_new_rounded,
            onPressed: () => _showPreviewDialog(context),
          ),
          const SizedBox(height: AppSpacing.s8),
          AppButton(
            label: 'Tampilkan berhasil',
            variant: AppButtonVariant.secondary,
            onPressed: () => _showSuccess(context),
          ),
          const SizedBox(height: AppSpacing.s8),
          const AppButton(
            label: 'Sedang menyimpan',
            onPressed: null,
            isLoading: true,
          ),
          const SizedBox(height: AppSpacing.s24),
          const _SectionTitle('Keadaan layar'),
          const SizedBox(height: AppSpacing.s12),
          const AppCard(
            child: SizedBox(
              height: AppSizes.statePreviewHeight,
              child: LoadingView(message: 'Menyiapkan jurnal...'),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          AppCard(
            child: SizedBox(
              height: AppSizes.statePreviewHeight,
              child: EmptyView(
                message: 'Seduhan pertamamu akan muncul di sini.',
                actionLabel: 'Mulai nanti',
                onActionPressed: () => _showSuccess(context),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          AppCard(
            child: SizedBox(
              height: AppSizes.statePreviewHeight,
              child: ErrorView(
                message: 'Data belum bisa dimuat. Silakan coba lagi.',
                onRetry: () => _showSuccess(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreviewDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Komponen dialog',
        message: 'Dialog memakai bentuk, jarak, dan tombol dari tema Tetes.',
        primaryLabel: 'Mengerti',
        onPrimaryPressed: () => Navigator.of(dialogContext).pop(),
        secondaryLabel: 'Tutup',
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  void _showSuccess(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Komponen berhasil dijalankan.')),
      );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.s8),
              Text(message),
            ],
          ),
        ),
      ],
    );
  }
}
