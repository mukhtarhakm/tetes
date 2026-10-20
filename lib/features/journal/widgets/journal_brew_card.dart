import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/status_pill.dart';
import '../journal_model.dart';

class JournalBrewCard extends StatelessWidget {
  const JournalBrewCard({
    required this.item,
    required this.onTap,
    super.key,
  });

  final BrewJournalItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final ratioText = item.ratio % 1 == 0
        ? '1:${item.ratio.toInt()}'
        : '1:${item.ratio.toStringAsFixed(1)}';
    final durationText = _formatSeconds(item.totalTimeS);
    final (syncLabel, syncVariant) = switch (item.syncStatus) {
      'synced' => ('Tersinkron', StatusPillVariant.synced),
      'error' => ('Galat sync', StatusPillVariant.error),
      _ => ('Menunggu sync', StatusPillVariant.pending),
    };

    final content = Column(
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
                    item.beanName,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (item.beanRoastery != null &&
                      item.beanRoastery!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      item.beanRoastery!,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s4,
              runSpacing: AppSpacing.s4,
              alignment: WrapAlignment.end,
              children: [
                if (item.isBestBrew && !item.isCancelled)
                  const StatusPill(
                    label: 'Terbaik',
                    variant: StatusPillVariant.synced,
                  ),
                if (item.isCancelled)
                  const StatusPill(
                    label: 'Dibatalkan',
                    variant: StatusPillVariant.warning,
                  ),
                StatusPill(label: syncLabel, variant: syncVariant),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: AppSizes.navigationIcon, color: AppColors.inkSoft),
            const SizedBox(width: AppSpacing.s4),
            Text(
              _formatLocalBrewedAt(item.brewedAtUtc),
              style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Container(
          padding: AppInsets.chip,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.navigation),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ParamColumn(label: 'Rasio', value: ratioText),
              _ParamColumn(label: 'Suhu', value: '${item.waterTempC}°C'),
              _ParamColumn(
                label: 'Dosis & Waktu',
                value: '${item.doseG.toStringAsFixed(1)}g · $durationText',
              ),
              _ParamColumn(
                label: 'Skor',
                value: '★ ${item.tasteScore}/5',
                highlight: true,
              ),
            ],
          ),
        ),
        if (item.tasteTags.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s4,
            runSpacing: AppSpacing.s4,
            children: item.tasteTags
                .map((tag) => AppChip(label: tag))
                .toList(growable: false),
          ),
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Opacity(
          opacity: item.isCancelled ? 0.5 : 1.0,
          child: AppCard(child: content),
        ),
      ),
    );
  }

  static String _formatLocalBrewedAt(String utcString) {
    try {
      final dt = DateTime.parse(utcString).toLocal();
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
      final month = months[dt.month - 1];
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $month ${dt.year}, $hour:$minute';
    } catch (_) {
      return utcString;
    }
  }

  static String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _ParamColumn extends StatelessWidget {
  const _ParamColumn({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: AppColors.inkSoft,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: highlight ? AppColors.ink : null,
          ),
        ),
      ],
    );
  }
}
