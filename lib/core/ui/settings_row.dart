import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

enum SettingsIconTint { primary, accent, neutral }

/// Judul bagian di atas kartu pengaturan.
class SettingsSectionTitle extends StatelessWidget {
  const SettingsSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.s12),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
}

/// Pemisah tipis di antara baris, sejajar dengan awal teks.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(
      left: AppSizes.settingsIconCircle + AppSpacing.s12,
    ),
    child: Divider(
      height: AppSizes.dividerThickness,
      thickness: AppSizes.dividerThickness,
      color: AppColors.divider,
    ),
  );
}

/// Baris pengaturan: ikon bulat berwarna, judul, penjelasan, dan aksi di kanan.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.tint = SettingsIconTint.primary,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final SettingsIconTint tint;

  Color get _tintColor => switch (tint) {
    SettingsIconTint.primary => AppColors.primaryContainer,
    SettingsIconTint.accent => AppColors.accentSoft,
    SettingsIconTint.neutral => AppColors.background,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.settingsRowHeight),
      child: Row(
        children: [
          Container(
            width: AppSizes.settingsIconCircle,
            height: AppSizes.settingsIconCircle,
            decoration: BoxDecoration(color: _tintColor, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.ink),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.s8),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.innerCard),
        child: row,
      ),
    );
  }
}
