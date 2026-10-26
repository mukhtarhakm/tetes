import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../data/remote/chain_verifier.dart';
import '../state/chain_anchor_status.dart';

enum _Kind {
  unanchored,
  failed,
  pending,
  confirmed,
  match,
  mismatch,
  notFound,
  unknown,
}

/// Kartu status jangkar Sepolia di atas daftar Jurnal.
class ChainAnchorCard extends ConsumerStatefulWidget {
  const ChainAnchorCard({this.compact = false, super.key});

  /// Satu baris ringkas; diketuk membuka kartu lengkap di bottom sheet.
  final bool compact;

  @override
  ConsumerState<ChainAnchorCard> createState() => _ChainAnchorCardState();
}

class _ChainAnchorCardState extends ConsumerState<ChainAnchorCard> {
  bool _verifying = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(chainAnchorStatusProvider).asData?.value;
    if (status == null || status.phase == ChainAnchorPhase.noBrews) {
      return const SizedBox.shrink();
    }
    final kind = _kindOf(status);
    final view = _viewOf(kind, status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;
    final border = switch (kind) {
      _Kind.match => AppColors.primary,
      _Kind.mismatch || _Kind.notFound => AppColors.error,
      _ => null,
    };
    final explorerUrl = status.anchor?.explorerUrl;

    if (widget.compact) {
      return Semantics(
        button: true,
        label: '${view.title}. ${view.subtitle}. Ketuk untuk detail.',
        child: Material(
          color: isDark ? AppColors.surfaceDark : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.small),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: isDark
                  ? AppColors.surfaceDark
                  : AppColors.background,
              builder: (_) => const SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.s20,
                    AppSpacing.s16,
                    AppSpacing.s20,
                    AppSpacing.s20,
                  ),
                  child: SingleChildScrollView(child: ChainAnchorCard()),
                ),
              ),
            ),
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppSizes.minimumTouchTarget + 4,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              ),
              decoration: border == null
                  ? null
                  : BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.small),
                      border: Border.all(color: border, width: 2),
                    ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: view.iconBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ExcludeSemantics(
                      child: Icon(view.icon, color: view.iconColor, size: 18),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          view.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: view.titleColor,
                          ),
                        ),
                        Text(
                          view.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.inkSoft,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.innerCard),
        border: border == null ? null : Border.all(color: border, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: view.iconBackground,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: ExcludeSemantics(
                  child: Icon(view.icon, color: view.iconColor, size: 22),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      view.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: view.titleColor,
                      ),
                    ),
                    Text(
                      view.subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (view.chip != null) ...[
                const SizedBox(width: AppSpacing.s8),
                Container(
                  padding: AppInsets.statusPill,
                  decoration: BoxDecoration(
                    color: view.iconBackground,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    view.chip!,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (view.body != null) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(view.body!, style: textTheme.bodyMedium),
          ],
          if (_hasButtons(kind, explorerUrl)) ...[
            const SizedBox(height: AppSpacing.s12),
            _buttons(kind, explorerUrl),
          ],
        ],
      ),
    );
  }

  bool _hasButtons(_Kind kind, String? explorerUrl) => switch (kind) {
    _Kind.unanchored || _Kind.failed => false,
    _Kind.pending => explorerUrl != null,
    _ => true,
  };

  Widget _buttons(_Kind kind, String? explorerUrl) {
    final verifyLabel = switch (kind) {
      _Kind.confirmed => 'Verifikasi',
      _ => 'Verifikasi ulang',
    };
    final verify = kind == _Kind.confirmed
        ? FilledButton(
            onPressed: _verifying ? null : _verify,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(0, AppSizes.minimumTouchTarget),
              shape: const StadiumBorder(),
            ),
            child: _verifying
                ? const SizedBox.square(
                    dimension: AppSizes.buttonProgress,
                    child: CircularProgressIndicator(
                      strokeWidth: AppSizes.progressStroke,
                      color: AppColors.ink,
                    ),
                  )
                : Text(verifyLabel),
          )
        : AppButton(
            label: verifyLabel,
            variant: AppButtonVariant.secondary,
            isLoading: _verifying,
            onPressed: _verify,
          );
    final explorer = explorerUrl == null
        ? null
        : AppButton(
            label: kind == _Kind.pending
                ? 'Lihat transaksi di Etherscan'
                : 'Etherscan',
            variant: AppButtonVariant.secondary,
            icon: Icons.open_in_new_rounded,
            onPressed: () => _copyExplorer(explorerUrl),
          );

    if (kind == _Kind.pending) {
      return explorer ?? const SizedBox.shrink();
    }
    if (kind == _Kind.mismatch ||
        kind == _Kind.notFound ||
        kind == _Kind.unknown) {
      return SizedBox(width: double.infinity, child: verify);
    }
    return Row(
      children: [
        Expanded(child: verify),
        if (explorer != null) ...[
          const SizedBox(width: AppSpacing.s8),
          Expanded(child: explorer),
        ],
      ],
    );
  }

  Future<void> _verify() async {
    if (_verifying) {
      return;
    }
    setState(() => _verifying = true);
    try {
      final result = await ref
          .read(chainAnchorStatusProvider.notifier)
          .verifyNow();
      if (mounted && result is Unreachable) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Jaringan Sepolia tidak terjangkau. Coba lagi nanti.',
              ),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  Future<void> _copyExplorer(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Tautan Etherscan disalin. Tempel di browser untuk membukanya.',
          ),
        ),
      );
  }

  _Kind _kindOf(ChainAnchorStatus status) {
    switch (status.phase) {
      case ChainAnchorPhase.noBrews:
      case ChainAnchorPhase.unanchored:
        return _Kind.unanchored;
      case ChainAnchorPhase.failed:
        return _Kind.failed;
      case ChainAnchorPhase.pending:
        return _Kind.pending;
      case ChainAnchorPhase.confirmed:
        return switch (status.anchor?.verifyResult) {
          'match' => _Kind.match,
          'mismatch' => _Kind.mismatch,
          'not_found' => _Kind.notFound,
          'unknown' => _Kind.unknown,
          _ => _Kind.confirmed,
        };
    }
  }

  _View _viewOf(_Kind kind, ChainAnchorStatus status) {
    final anchor = status.anchor;
    final seq = anchor == null ? '' : '#${anchor.seq}';
    switch (kind) {
      case _Kind.unanchored:
        return const _View(
          icon: Icons.link_rounded,
          iconBackground: AppColors.divider,
          iconColor: AppColors.inkSoft,
          title: 'Belum dicatat',
          subtitle: 'Dicatat otomatis setelah sinkronisasi',
        );
      case _Kind.failed:
        return _View(
          icon: Icons.link_rounded,
          iconBackground: AppColors.divider,
          iconColor: AppColors.inkSoft,
          title: 'Belum dicatat',
          subtitle: status.message ?? 'Pencatatan gagal. Coba lagi nanti.',
        );
      case _Kind.pending:
        return _View(
          icon: Icons.schedule_rounded,
          iconBackground: AppColors.stage1Soft,
          iconColor: AppColors.ink,
          title: 'Menunggu konfirmasi',
          subtitle: 'Seduhan $seq',
          chip: 'Menunggu',
          body:
              'Transaksi sudah dikirim. Konfirmasi di Sepolia biasanya butuh beberapa detik sampai menit.',
        );
      case _Kind.confirmed:
        return _View(
          icon: Icons.link_rounded,
          iconBackground: AppColors.accentSoft,
          iconColor: AppColors.ink,
          title: 'Tercatat di Sepolia',
          subtitle: _formatWib(anchor?.anchoredAt),
          chip: 'Terkonfirmasi',
          body:
              'Riwayat seduhan sampai seduhan $seq sudah dicatat di blockchain publik.',
        );
      case _Kind.match:
        return _View(
          icon: Icons.check_rounded,
          iconBackground: AppColors.accentSoft,
          iconColor: AppColors.ink,
          title: 'Cocok dengan blockchain',
          subtitle: 'Diperiksa ${_formatWib(anchor?.verifiedAt)}',
          body:
              'Rantai seduhan di perangkat ini dihitung ulang dan hasilnya sama dengan hash yang tercatat di Sepolia.',
        );
      case _Kind.mismatch:
        return _View(
          icon: Icons.warning_amber_rounded,
          iconBackground: AppColors.stage4Soft,
          iconColor: AppColors.error,
          titleColor: AppColors.error,
          title: 'Tidak cocok',
          subtitle: 'Seduhan $seq',
          body:
              'Hash di blockchain berbeda dengan hasil hitung ulang rantai di perangkat ini. Data seduhan mungkin berubah atau rusak.',
        );
      case _Kind.notFound:
        return _View(
          icon: Icons.warning_amber_rounded,
          iconBackground: AppColors.stage4Soft,
          iconColor: AppColors.error,
          titleColor: AppColors.error,
          title: 'Tidak ditemukan di blockchain',
          subtitle: 'Seduhan $seq',
          body: 'Kontrak tidak memiliki catatan untuk akun ini.',
        );
      case _Kind.unknown:
        return const _View(
          icon: Icons.info_outline_rounded,
          iconBackground: AppColors.divider,
          iconColor: AppColors.ink,
          title: 'Belum bisa dibandingkan',
          subtitle: 'Jangkar lebih baru dari data di sini',
          body:
              'Jangkar di rantai lebih baru dari data di perangkat ini. Sinkronkan dari Beranda, lalu verifikasi lagi.',
        );
    }
  }

  static const _months = [
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

  static String _formatWib(String? iso) {
    final parsed = iso == null ? null : DateTime.tryParse(iso);
    if (parsed == null) {
      return '-';
    }
    final wib = parsed.toUtc().add(const Duration(hours: 7));
    String two(int value) => value.toString().padLeft(2, '0');
    return '${wib.day} ${_months[wib.month - 1]} ${wib.year}, '
        '${two(wib.hour)}.${two(wib.minute)} WIB';
  }
}

class _View {
  const _View({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.chip,
    this.body,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final String? chip;
  final String? body;
}
