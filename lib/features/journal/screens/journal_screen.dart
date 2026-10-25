import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_text_field.dart';
import '../../../core/ui/state_views.dart';
import '../../anchor/widgets/chain_anchor_card.dart';
import '../../brew/screens/brew_setup_screen.dart';
import '../state/journal_controller.dart';
import '../widgets/journal_brew_card.dart';
import '../widgets/journal_filter_sheet.dart';
import 'brew_compare_screen.dart';
import 'brew_detail_screen.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  double _bottomBarHeight = 0.0;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      ref.read(journalFilterProvider.notifier).setSearchQuery(query);
    });
  }

  void _toggleBrewSelection(String brewId) {
    final success = ref.read(journalSelectionProvider.notifier).toggle(brewId);
    if (!success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Hanya dapat memilih tepat dua seduhan untuk dibandingkan.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<JournalSelectionState>(journalSelectionProvider, (previous, next) {
      if (!next.isActive && (previous?.isActive ?? false)) {
        if (_bottomBarHeight != 0.0) {
          setState(() => _bottomBarHeight = 0.0);
        }
      }
    });

    final textTheme = Theme.of(context).textTheme;
    final filter = ref.watch(journalFilterProvider);
    final brewsAsync = ref.watch(journalBrewsProvider);
    final selectionState = ref.watch(journalSelectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jurnal'),
        centerTitle: false,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Status jangkar blockchain
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s8,
                AppSpacing.s20,
                AppSpacing.s4,
              ),
              child: ChainAnchorCard(compact: true),
            ),

            // Pencarian & Tombol Filter
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s8,
                AppSpacing.s20,
                AppSpacing.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _searchController,
                      hintText: 'Cari biji, roastery, tag, catatan...',
                      isSearch: true,
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  IconButton.filledTonal(
                    icon: Badge(
                      isLabelVisible: filter.isFiltered,
                      child: const Icon(Icons.tune_rounded),
                    ),
                    onPressed: () => JournalFilterSheet.show(context),
                  ),
                ],
              ),
            ),

            // Baris Info Hasil & Tombol Mode Pilih
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s20,
                vertical: AppSpacing.s4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      brewsAsync.maybeWhen(
                        data: (brews) => Text(
                          '${brews.length} seduhan',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        orElse: () => const SizedBox.shrink(),
                      ),
                      if (filter.isFiltered) ...[
                        const SizedBox(width: AppSpacing.s8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Reset filter'),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(journalFilterProvider.notifier).reset();
                          },
                        ),
                      ],
                    ],
                  ),
                  if (!selectionState.isActive)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                      label: const Text('Bandingkan'),
                      onPressed: () {
                        ref.read(journalSelectionProvider.notifier).activate();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s4),

            // Daftar Seduhan & Bar Aksi Bawah
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: brewsAsync.when(
                      loading: () =>
                          const LoadingView(message: 'Memuat jurnal seduhan...'),
                      error: (_, _) => Padding(
                        padding: AppInsets.screen,
                        child: ErrorView(
                          message: 'Gagal memuat jurnal seduhan.',
                          onRetry: () => ref.invalidate(journalBrewsProvider),
                        ),
                      ),
                      data: (brews) {
                        if (brews.isEmpty) {
                          if (!filter.isFiltered) {
                            return Padding(
                              padding: AppInsets.screen,
                              child: EmptyView(
                                title: 'Belum ada seduhan',
                                message:
                                    'Mulai seduh V60 pertamamu dan catat hasilnya di sini.',
                                icon: Icons.coffee_rounded,
                                actionLabel: 'Mulai seduh',
                                onActionPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const BrewSetupScreen(),
                                  ),
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding: AppInsets.screen,
                            child: EmptyView(
                              title: 'Tidak ada seduhan yang cocok',
                              message:
                                  'Coba ubah kata kunci pencarian atau atur ulang filter.',
                              icon: Icons.filter_alt_off_outlined,
                              actionLabel: 'Reset filter',
                              onActionPressed: () {
                                _searchController.clear();
                                ref.read(journalFilterProvider.notifier).reset();
                              },
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.s20,
                            AppSpacing.s8,
                            AppSpacing.s20,
                            AppSpacing.s16 +
                                (selectionState.isActive
                                    ? _bottomBarHeight
                                    : 0.0),
                          ),
                          itemCount: brews.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.s12),
                          itemBuilder: (context, index) {
                            final item = brews[index];
                            final isSelected =
                                selectionState.isSelected(item.id);

                            return JournalBrewCard(
                              item: item,
                              selectable: selectionState.isActive,
                              selected: isSelected,
                              onSelectChanged: (_) =>
                                  _toggleBrewSelection(item.id),
                              onLongPress: () {
                                if (!selectionState.isActive) {
                                  ref
                                      .read(journalSelectionProvider.notifier)
                                      .activate(item.id);
                                }
                              },
                              onTap: () {
                                if (selectionState.isActive) {
                                  _toggleBrewSelection(item.id);
                                } else {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          BrewDetailScreen(brewId: item.id),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (selectionState.isActive)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _BottomActionBar(
                        selectionCount: selectionState.selectedIds.length,
                        onCancel: () => ref
                            .read(journalSelectionProvider.notifier)
                            .reset(),
                        onCompare: selectionState.selectedIds.length == 2
                            ? () {
                                final ids =
                                    selectionState.selectedIds.toList();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BrewCompareScreen(
                                      brewId1: ids[0],
                                      brewId2: ids[1],
                                    ),
                                  ),
                                );
                              }
                            : null,
                        onHeightChanged: (h) {
                          if (mounted && (_bottomBarHeight - h).abs() > 0.5) {
                            setState(() => _bottomBarHeight = h);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatefulWidget {
  const _BottomActionBar({
    required this.selectionCount,
    required this.onCancel,
    required this.onCompare,
    required this.onHeightChanged,
  });

  final int selectionCount;
  final VoidCallback onCancel;
  final VoidCallback? onCompare;
  final ValueChanged<double> onHeightChanged;

  @override
  State<_BottomActionBar> createState() => _BottomActionBarState();
}

class _BottomActionBarState extends State<_BottomActionBar> {
  @override
  void initState() {
    super.initState();
    _reportHeight();
  }

  @override
  void didUpdateWidget(covariant _BottomActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reportHeight();
  }

  void _reportHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final height = context.size?.height ?? 0.0;
        if (height > 0) {
          widget.onHeightChanged(height);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final statusText = switch (widget.selectionCount) {
      0 => 'Pilih 2 seduhan',
      1 => 'Pilih 1 lagi',
      _ => '2 dipilih',
    };

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s12,
          ),
          child: Row(
            children: [
              Text(
                statusText,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Batal'),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: AppButton(
                  label: 'Bandingkan',
                  onPressed: widget.onCompare,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
