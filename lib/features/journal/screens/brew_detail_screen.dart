import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_dialog.dart';
import '../../../core/ui/state_views.dart';
import '../../../core/ui/status_pill.dart';
import '../../../data/remote/ai_client.dart';
import '../../../data/repositories/brew_repo.dart';
import '../../../data/secure/session_storage.dart';
import '../../auth/session/force_logout.dart';
import '../../auth/state/auth_providers.dart';
import '../../auth/state/session_controller.dart';
import '../../beans/state/bean_providers.dart';
import '../../brew/ai_brew.dart';
import '../../brew/brew_plan.dart';
import '../../brew/screens/brew_setup_screen.dart';
import '../../brew/state/brew_setup_controller.dart';
import '../../brew/state/ai_client_provider.dart';
import '../journal_model.dart';
import '../state/journal_controller.dart';

class BrewDetailScreen extends ConsumerWidget {
  const BrewDetailScreen({required this.brewId, super.key});

  final String brewId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(brewDetailProvider(brewId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Seduhan')),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => const LoadingView(message: 'Memuat detail seduhan...'),
          error: (_, _) => Padding(
            padding: AppInsets.screen,
            child: ErrorView(
              message: 'Detail seduhan tidak dapat dimuat.',
              onRetry: () => ref.invalidate(brewDetailProvider(brewId)),
            ),
          ),
          data: (data) {
            if (data == null) {
              return const Padding(
                padding: AppInsets.screen,
                child: EmptyView(
                  title: 'Seduhan tidak ditemukan',
                  message:
                      'Data seduhan mungkin sudah terhapus atau bukan milikmu.',
                  icon: Icons.coffee_outlined,
                ),
              );
            }
            return _BrewDetailContent(key: ValueKey(data.item.id), data: data);
          },
        ),
      ),
    );
  }
}

class _BrewDetailContent extends ConsumerStatefulWidget {
  const _BrewDetailContent({required this.data, super.key});

  final BrewDetailData data;

  @override
  ConsumerState<_BrewDetailContent> createState() => _BrewDetailContentState();
}

class _BrewDetailContentState extends ConsumerState<_BrewDetailContent> {
  final _cooldown = AiRequestCooldown();
  bool _diagnosing = false;
  int _cooldownSeconds = 0;
  String? _diagnosisNotice;
  Map<String, dynamic>? _fallback;
  BrewPlan? _fallbackPlan;

  @override
  void dispose() {
    _cooldown.dispose();
    super.dispose();
  }

  bool get _current => mounted && ModalRoute.of(context)?.isCurrent == true;

  Future<void> _requestDiagnosis() async {
    final data = widget.data;
    if (_diagnosing || _cooldown.active || data.item.isCancelled) return;
    setState(() => _diagnosing = true);
    SessionState session;
    try {
      session = await ref.read(sessionControllerProvider.future);
    } catch (_) {
      if (mounted) {
        setState(() {
          _diagnosing = false;
          _diagnosisNotice = 'Sesi tidak tersedia.';
        });
      }
      return;
    }
    if (!mounted ||
        !_current ||
        session.userId != data.item.userId ||
        session.status != SessionStatus.authenticated) {
      if (mounted) setState(() => _diagnosing = false);
      return;
    }
    final sessionStorage = ref.read(sessionStorageProvider);
    final sessionController = ref.read(sessionControllerProvider.notifier);
    if (data.aiAdvice?.isNotEmpty == true) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AppDialog(
          title: 'Minta ulang diagnosa?',
          message: 'Saran AI yang tersimpan akan diganti.',
          primaryLabel: 'Minta ulang',
          onPrimaryPressed: () => Navigator.of(dialogContext).pop(true),
          secondaryLabel: 'Batal',
          onSecondaryPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      );
      if (confirmed != true || !_current) {
        if (mounted) setState(() => _diagnosing = false);
        return;
      }
    }
    setState(() {
      _diagnosisNotice = null;
      _fallback = null;
      _fallbackPlan = null;
    });
    try {
      final repo = await ref.read(brewRepositoryProvider.future);
      final beanRepo = await ref.read(beanRepositoryProvider.future);
      final bean = await beanRepo.findById(
        userId: session.userId!,
        id: data.item.beanId,
      );
      if (!_current) return;
      if (bean == null) {
        throw StateError('Biji tidak ditemukan');
      }
      final history = await repo.findAiHistory(
        userId: session.userId!,
        beanId: bean.id,
      );
      if (!_current) return;
      final response = await ref
          .read(aiClientProvider)
          .diagnose(
            userId: session.userId!,
            payload: AiBrew.diagnoseSavedPayload(
              bean: bean,
              detail: data,
              history: history
                  .where((entry) => entry.item.id != data.item.id)
                  .toList(),
            ),
          );
      if (!_current) return;
      final plan = data.toBrewPlan();
      if (!AiBrew.validDiagnosis(response) ||
          plan == null ||
          AiBrew.planFromDiagnosis(base: plan, diagnosis: response) == null) {
        _showFallback(
          'Saran AI tidak dapat dipakai sebagai rencana seduh. Menampilkan saran sederhana.',
        );
        return;
      }
      await repo.updateAiAdvice(
        userId: session.userId!,
        brewId: data.item.id,
        aiAdvice: jsonEncode(response),
      );
      if (!_current) return;
      ref.invalidate(brewDetailProvider(data.item.id));
      ref.invalidate(journalBrewsProvider);
    } on AiException catch (error) {
      if (error.failure == AiFailure.unauthorized) {
        try {
          final stored = await sessionStorage.readSession();
          if (stored?.userId == session.userId) {
            await forceLogoutOnUnauthorized(sessionController);
          }
        } on SessionStorageException {
          // Sesi aktif tidak dapat dipastikan.
        }
      } else {
        if (error.failure == AiFailure.network ||
            error.failure == AiFailure.rateLimited ||
            error.failure == AiFailure.invalidOutput ||
            error.failure == AiFailure.upstream ||
            error.failure == AiFailure.timeout) {
          _cooldown.start((seconds) {
            if (mounted) setState(() => _cooldownSeconds = seconds);
          });
        }
        if (_current) {
          _showFallback(
            error.upstreamStatus == 503 || error.upstreamStatus == 429
                ? 'Layanan AI sedang sibuk, coba lagi sebentar.'
                : '${error.message} Menampilkan saran sederhana.',
          );
        }
      }
    } on BrewSaveException catch (error) {
      if (_current) setState(() => _diagnosisNotice = error.message);
    } catch (_) {
      if (_current) {
        _showFallback('Diagnosa AI gagal. Menampilkan saran sederhana.');
      }
    } finally {
      if (mounted) setState(() => _diagnosing = false);
    }
  }

  void _showFallback(String notice) {
    final plan = widget.data.toBrewPlan();
    if (plan == null) {
      setState(() => _diagnosisNotice = notice);
      return;
    }
    final fallback = AiBrew.fallbackDiagnosis(
      plan: plan,
      tasteScore: widget.data.item.tasteScore,
      tasteTags: widget.data.item.tasteTags,
    );
    setState(() {
      _fallback = fallback;
      _fallbackPlan = AiBrew.planFromDiagnosis(base: plan, diagnosis: fallback);
      _diagnosisNotice = notice;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final textTheme = Theme.of(context).textTheme;
    final item = data.item;

    final ratioText = item.ratio % 1 == 0
        ? '1:${item.ratio.toInt()}'
        : '1:${item.ratio.toStringAsFixed(1)}';
    final (syncLabel, syncVariant) = switch (item.syncStatus) {
      'synced' => ('Tersinkron', StatusPillVariant.synced),
      'error' => ('Galat sync', StatusPillVariant.error),
      _ => ('Menunggu sync', StatusPillVariant.pending),
    };
    final shortHash = item.hash.length >= 8
        ? item.hash.substring(0, 8)
        : item.hash;
    final adviceText = _fallback == null
        ? _formatAdvice(data.aiAdvice)
        : AiBrew.diagnosisSummary(_fallback!);
    final savedPlan = _planFromSavedAdvice(data);
    final nextPlan = _fallbackPlan ?? savedPlan;

    return ListView(
      padding: AppInsets.screen,
      children: [
        // Status & Biji Header
        AppCard(
          child: Column(
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
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (item.beanRoastery != null &&
                            item.beanRoastery!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s4),
                          Text(
                            item.beanRoastery!,
                            style: textTheme.bodyMedium?.copyWith(
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
                  Icon(
                    Icons.calendar_today_outlined,
                    size: AppSizes.navigationIcon,
                    color: AppColors.inkSoft,
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Text(
                    _formatLocalBrewedAt(item.brewedAtUtc),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Ringkasan Parameter
        Text('Ringkasan Parameter', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s8),
        AppCard(
          child: Column(
            children: [
              _DetailRow(
                label: 'Dosis kopi',
                value: '${item.doseG.toStringAsFixed(1)} g',
              ),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Rasio air', value: ratioText),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Suhu air', value: '${item.waterTempC}°C'),
              const Divider(color: AppColors.divider),
              _DetailRow(label: 'Ukuran grind', value: item.grind.label),
              const Divider(color: AppColors.divider),
              _DetailRow(
                label: 'Total waktu aktif',
                value: _formatSeconds(item.totalTimeS),
              ),
              if (data.finalDrawdownS != null) ...[
                const Divider(color: AppColors.divider),
                _DetailRow(
                  label: 'Waktu drawdown',
                  value: '${data.finalDrawdownS} detik',
                ),
              ],
              const Divider(color: AppColors.divider),
              _DetailRow(
                label: 'Biaya seduhan',
                value: item.costIdr != null
                    ? 'Rp ${item.costIdr!.toStringAsFixed(0)}'
                    : 'Tidak tersedia',
              ),
              const Divider(color: AppColors.divider),
              _DetailRow(
                label: 'Skor rasa',
                value: '★ ${item.tasteScore} / 5',
                highlight: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Tabel Tahap
        Text('Tabel Tahap Seduh', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s8),
        AppCard(
          padding: EdgeInsets.zero,
          child: Table(
            border: TableBorder(
              horizontalInside: BorderSide(color: AppColors.divider),
            ),
            columnWidths: const {
              0: FlexColumnWidth(2.5),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2.5),
              3: FlexColumnWidth(2),
            },
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.card),
                  ),
                ),
                children: [
                  _TableHeader('Tahap'),
                  _TableHeader('Waktu'),
                  _TableHeader('Target Air'),
                  _TableHeader('Aktual'),
                ],
              ),
              ...data.stages.map((stage) {
                final start = _formatSeconds(stage.targetStartS);
                final end = _formatSeconds(
                  stage.targetStartS + stage.targetDurationS,
                );
                return TableRow(
                  children: [
                    _TableCell(stage.name.label),
                    _TableCell('$start - $end'),
                    _TableCell(
                      '${stage.targetPourG.toStringAsFixed(0)}g (${stage.targetWaterCumG.toStringAsFixed(0)}g)',
                    ),
                    _TableCell(
                      stage.actualWaterG != null
                          ? '${stage.actualWaterG!.toStringAsFixed(0)}g'
                          : '-',
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Tag Rasa Pengguna vs Notes Roastery
        Text('Rasa & Catatan Roastery', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s8),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tag Rasa Pilihanmu',
                style: textTheme.labelLarge?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: AppSpacing.s8),
              if (item.tasteTags.isEmpty)
                Text('Tidak ada tag rasa.', style: textTheme.bodySmall)
              else
                Wrap(
                  spacing: AppSpacing.s4,
                  runSpacing: AppSpacing.s4,
                  children: item.tasteTags
                      .map((tag) => AppChip(label: tag))
                      .toList(growable: false),
                ),
              const SizedBox(height: AppSpacing.s16),
              const Divider(color: AppColors.divider),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Notes Roastery',
                style: textTheme.labelLarge?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: AppSpacing.s8),
              if (data.roasteryNotesTags.isEmpty &&
                  (data.roasteryNotesText == null ||
                      data.roasteryNotesText!.isEmpty))
                Text(
                  'Tidak ada catatan dari roastery.',
                  style: textTheme.bodySmall,
                )
              else ...[
                if (data.roasteryNotesTags.isNotEmpty)
                  Wrap(
                    spacing: AppSpacing.s4,
                    runSpacing: AppSpacing.s4,
                    children: data.roasteryNotesTags
                        .map((tag) => AppChip(label: tag))
                        .toList(growable: false),
                  ),
                if (data.roasteryNotesText != null &&
                    data.roasteryNotesText!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Text(data.roasteryNotesText!, style: textTheme.bodyMedium),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Catatan
        Text('Catatan', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s8),
        AppCard(
          child: Text(
            data.notes != null && data.notes!.isNotEmpty
                ? data.notes!
                : 'Tidak ada catatan untuk seduhan ini.',
            style: textTheme.bodyMedium?.copyWith(
              color: data.notes != null && data.notes!.isNotEmpty
                  ? AppColors.ink
                  : AppColors.inkSoft,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        Text('Diagnosa AI', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s8),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_fallback != null)
                const StatusPill(
                  label: 'Saran sederhana',
                  variant: StatusPillVariant.warning,
                ),
              if (_diagnosisNotice != null) Text(_diagnosisNotice!),
              Text(
                adviceText,
                style: textTheme.bodyMedium?.copyWith(
                  color:
                      _fallback != null ||
                          data.aiAdvice != null && data.aiAdvice!.isNotEmpty
                      ? AppColors.ink
                      : AppColors.inkSoft,
                ),
              ),
              if (_fallback != null ||
                  data.aiAdvice != null && data.aiAdvice!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Saran, bukan kepastian. Coba dan catat hasilnya.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.inkSoft,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!item.isCancelled) ...[
          const SizedBox(height: AppSpacing.s8),
          AppButton(
            label: _cooldownSeconds > 0
                ? 'Coba lagi dalam $_cooldownSeconds detik'
                : data.aiAdvice?.isNotEmpty == true
                ? 'Minta ulang'
                : 'Minta Diagnosa AI',
            variant: AppButtonVariant.secondary,
            isLoading: _diagnosing,
            onPressed: _diagnosing || _cooldownSeconds > 0
                ? null
                : _requestDiagnosis,
          ),
        ],
        if (nextPlan != null) ...[
          const SizedBox(height: AppSpacing.s8),
          AppButton(
            label: 'Terapkan ke seduhan berikutnya',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BrewSetupScreen(initialPlan: nextPlan),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s16),

        // Integritas Rantai Hash
        Text('Integritas Data', style: textTheme.titleMedium),
        const SizedBox(height: AppSpacing.s8),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Nomor Urut (Seq)', value: '#${item.seq}'),
              const Divider(color: AppColors.divider),
              _DetailRow(
                label: 'Hash (8 karakter pertama)',
                value: '$shortHash...',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s24),

        // Tombol Aksi
        AppButton(
          label: 'Seduh lagi dengan pengaturan ini',
          icon: Icons.coffee_rounded,
          onPressed: () => _handleBrewAgain(context),
        ),
        if (!item.isCancelled) ...[
          const SizedBox(height: AppSpacing.s12),
          AppButton(
            label: 'Tandai dibatalkan',
            variant: AppButtonVariant.secondary,
            icon: Icons.cancel_outlined,
            onPressed: () => _handleCancel(context, ref),
          ),
        ],
        const SizedBox(height: AppSpacing.s32),
      ],
    );
  }

  void _handleBrewAgain(BuildContext context) {
    final data = widget.data;
    if (data.isBeanArchived) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biji kopi ini sudah diarsipkan dan tidak dapat diseduh lagi.',
          ),
        ),
      );
      return;
    }

    final plan = data.toBrewPlan();
    if (plan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan seduh ini tidak valid untuk dibuat ulang.'),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BrewSetupScreen(initialPlan: plan)),
    );
  }

  static String _formatAdvice(String? advice) {
    if (advice == null || advice.isEmpty) {
      return 'Belum ada saran AI untuk seduhan ini.';
    }
    try {
      final decoded = jsonDecode(advice);
      if (decoded is Map<String, dynamic> && AiBrew.validDiagnosis(decoded)) {
        return AiBrew.diagnosisSummary(decoded);
      }
    } catch (_) {
      // Saran lama dapat tersimpan sebagai teks biasa.
    }
    return advice;
  }

  BrewPlan? _planFromSavedAdvice(BrewDetailData data) {
    final plan = data.toBrewPlan();
    if (plan == null || data.aiAdvice == null) return null;
    try {
      final advice = jsonDecode(data.aiAdvice!);
      return advice is Map<String, dynamic>
          ? AiBrew.planFromDiagnosis(base: plan, diagnosis: advice)
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleCancel(BuildContext context, WidgetRef ref) async {
    final data = widget.data;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Tandai dibatalkan?',
        message:
            'Status seduhan akan diubah menjadi dibatalkan. Catatan tetap tersimpan dalam rantai hash, namun stok biji kopi akan bertambah kembali dan pengaturan terbaik dihitung ulang.',
        primaryLabel: 'Tandai dibatalkan',
        onPrimaryPressed: () => Navigator.of(dialogContext).pop(true),
        secondaryLabel: 'Batal',
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(false),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final repo = await ref.read(brewRepositoryProvider.future);
      final success = await repo.cancelBrew(
        userId: data.item.userId,
        brewId: data.item.id,
      );

      if (!context.mounted) return;

      if (success) {
        // Invalidate providers
        ref.invalidate(journalBrewsProvider);
        ref.invalidate(brewDetailProvider(data.item.id));
        ref.invalidate(beanListProvider);
        ref.invalidate(beanDetailProvider(data.item.beanId));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seduhan berhasil ditandai dibatalkan.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Seduhan tidak dapat dibatalkan atau sudah dibatalkan.',
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan saat membatalkan seduhan.'),
          ),
        );
      }
    }
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlight ? AppColors.ink : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s12,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s12,
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
