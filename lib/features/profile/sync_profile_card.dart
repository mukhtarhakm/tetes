import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/status_pill.dart';
import '../../data/sync/sync_service.dart';

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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Sinkronisasi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.s8),
          if (loading)
            const Text('Memuat status sinkronisasi...')
          else if (error != null) ...[
            const StatusPill(label: 'Galat', variant: StatusPillVariant.error),
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
          const SizedBox(height: AppSpacing.s8),
          AppButton(
            label: 'Tarik data dari server',
            onPressed: loading ? null : onPull,
          ),
          if (status?.lastPullAt != null) ...[
            const SizedBox(height: AppSpacing.s8),
            Text('Tarik terakhir: ${status!.lastPullAt}'),
            Text(
              status!.pullSummary?['error'] is String
                  ? 'Hasil tarik: ${status!.pullSummary!['error']}'
                  : 'Hasil tarik: ${status!.pullSummary?['beans'] ?? 0} biji, ${status!.pullSummary?['brews'] ?? 0} seduhan.',
            ),
          ],
        ],
      ),
    );
  }
}
