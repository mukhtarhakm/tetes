import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/status_pill.dart';
import '../../data/sync/sync_service.dart';
import 'profile_format.dart';

class SyncProfileCard extends StatelessWidget {
  const SyncProfileCard({
    required this.status,
    required this.error,
    required this.loading,
    required this.onSync,
    required this.onPull,
    super.key,
  });

  final SyncStatus? status;
  final String? error;
  final bool loading;
  final VoidCallback onSync;
  final VoidCallback onPull;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: AppColors.inkSoft);
    final now = DateTime.now();
    final current = status;
    final accepted = current?.summary?['accepted'];
    final acceptedCount = accepted is Map
        ? const [
            'beans',
            'brews',
            'events',
            'game_scores',
            'feedback',
          ].fold<int>(
            0,
            (total, table) => total + ((accepted[table] as num?) ?? 0).toInt(),
          )
        : 0;
    final lastSync = DateTime.tryParse(current?.lastSyncAt ?? '')?.toLocal();
    final lastPull = DateTime.tryParse(current?.lastPullAt ?? '')?.toLocal();
    final pullError = current?.pullSummary?['error'];
    final pullResult = pullError is String
        ? 'Gagal: $pullError'
        : '${current?.pullSummary?['beans'] ?? 0} biji, ${current?.pullSummary?['brews'] ?? 0} seduhan';

    final Widget pill;
    if (loading) {
      pill = const StatusPill(
        label: 'Memuat...',
        variant: StatusPillVariant.pending,
      );
    } else if (error != null) {
      pill = const StatusPill(
        label: 'Galat',
        variant: StatusPillVariant.error,
      );
    } else if (current == null) {
      pill = const StatusPill(
        label: 'Belum tersedia',
        variant: StatusPillVariant.pending,
      );
    } else if (current.errorCount > 0) {
      pill = StatusPill(
        label: '${current.errorCount} perlu dicoba ulang',
        variant: StatusPillVariant.error,
      );
    } else if (current.pendingCount > 0) {
      pill = StatusPill(
        label: '${current.pendingCount} data menunggu',
        variant: StatusPillVariant.pending,
      );
    } else {
      pill = const StatusPill(
        label: 'Semua tersinkron',
        variant: StatusPillVariant.synced,
      );
    }

    return AppCard(
      padding: AppInsets.settingsBlock,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              pill,
              Text(
                lastSync == null
                    ? 'Belum pernah sinkron'
                    : 'Terakhir: ${formatRelativeDateTime(lastSync, now)}',
                style: muted,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (error != null)
            Text(error!, style: muted)
          else if (current != null)
            Text(
              '${current.pendingCount} data menunggu · $acceptedCount diterima pada sinkron terakhir',
              style: muted,
            ),
          if (lastPull != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Ditarik ${formatRelativeDateTime(lastPull, now)}: $pullResult',
              style: muted,
            ),
          ],
          const SizedBox(height: AppSpacing.s16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Sinkronkan',
                  onPressed: loading ? null : onSync,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: AppButton(
                  label: 'Tarik data',
                  variant: AppButtonVariant.secondary,
                  onPressed: loading ? null : onPull,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
