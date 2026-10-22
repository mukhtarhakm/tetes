import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/ui/rating_stars.dart';
import '../../../core/utils/format_ratio.dart';
import '../journal_model.dart';

class JournalBrewCard extends StatelessWidget {
  const JournalBrewCard({
    required this.item,
    required this.onTap,
    this.selectable = false,
    this.selected = false,
    this.onSelectChanged,
    this.onLongPress,
    super.key,
  });

  final BrewJournalItem item;
  final VoidCallback onTap;
  final bool selectable;
  final bool selected;
  final ValueChanged<bool?>? onSelectChanged;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final ratioText = formatRatio(item.ratio);
    final durationText = _formatSeconds(item.totalTimeS);
    final (syncLabel, syncVariant) = switch (item.syncStatus) {
      'synced' => ('Tersinkron', StatusPillVariant.synced),
      'error' => ('Galat sync', StatusPillVariant.error),
      _ => ('Menunggu sync', StatusPillVariant.pending),
    };

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.beanName,
          softWrap: true,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        if (item.beanRoastery != null && item.beanRoastery!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            item.beanRoastery!,
            softWrap: true,
            style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
        ],
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s4,
          runSpacing: AppSpacing.s4,
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
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: AppSizes.navigationIcon,
              color: AppColors.inkSoft,
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Text(
                _formatLocalBrewedAt(item.brewedAtUtc),
                style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Container(
          width: double.infinity,
          padding: AppInsets.chip,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(AppRadius.navigation),
          ),
          child: Wrap(
            spacing: AppSpacing.s16,
            runSpacing: AppSpacing.s8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ParamColumn(label: 'Rasio', value: ratioText),
              _ParamColumn(label: 'Suhu', value: '${item.waterTempC}°C'),
              _ParamColumn(
                label: 'Dosis & Waktu',
                value: '${item.doseG.toStringAsFixed(1)}g · $durationText',
              ),
              _ParamColumn(
                label: 'Skor',
                valueWidget: RatingStars(score: item.tasteScore, compact: true),
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

    final cardWidget = AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selectable) ...[
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s8),
              child: Checkbox(
                value: selected,
                onChanged: onSelectChanged,
                activeColor: AppColors.primary,
                checkColor: AppColors.ink,
              ),
            ),
          ],
          Expanded(child: content),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: selectable ? () => onSelectChanged?.call(!selected) : onTap,
        onLongPress: onLongPress,
        child: Opacity(
          opacity: item.isCancelled ? 0.5 : 1.0,
          child: cardWidget,
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
  const _ParamColumn({required this.label, this.value, this.valueWidget});

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
        ),
        const SizedBox(height: AppSpacing.s4),
        if (valueWidget != null)
          valueWidget!
        else
          Text(
            value!,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
      ],
    );
  }
}
