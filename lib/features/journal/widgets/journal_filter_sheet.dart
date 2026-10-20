import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_chip.dart';
import '../../beans/bean_model.dart';
import '../../beans/state/bean_providers.dart';
import '../journal_model.dart';
import '../state/journal_controller.dart';

class JournalFilterSheet extends ConsumerStatefulWidget {
  const JournalFilterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      builder: (_) => const JournalFilterSheet(),
    );
  }

  @override
  ConsumerState<JournalFilterSheet> createState() => _JournalFilterSheetState();
}

class _JournalFilterSheetState extends ConsumerState<JournalFilterSheet> {
  late JournalFilter _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(journalFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final beansAsync = ref.watch(beanListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AppSpacing.s16,
                AppSpacing.s20,
                AppSpacing.s8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter & Urutkan', style: textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.divider, height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s20,
                  vertical: AppSpacing.s16,
                ),
                children: [
                  // Urutan
                  Text('Urutkan', style: textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: BrewSortOption.values.map((option) {
                      final selected = _draft.sortOption == option;
                      return AppChip(
                        label: option.label,
                        selected: selected,
                        onSelected: (_) {
                          setState(() {
                            _draft = _draft.copyWith(sortOption: option);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.s20),

                  // Biji Kopi
                  Text('Biji Kopi', style: textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.s8),
                  beansAsync.when(
                    data: (beans) {
                      if (beans.isEmpty) {
                        return Text(
                          'Belum ada biji kopi aktif.',
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.inkSoft,
                          ),
                        );
                      }
                      return Wrap(
                        spacing: AppSpacing.s8,
                        runSpacing: AppSpacing.s8,
                        children: beans.map((bean) {
                          final selected =
                              _draft.selectedBeanIds.contains(bean.id);
                          return AppChip(
                            label: bean.name,
                            selected: selected,
                            onSelected: (val) {
                              setState(() {
                                final current =
                                    Set<String>.of(_draft.selectedBeanIds);
                                if (val) {
                                  current.add(bean.id);
                                } else {
                                  current.remove(bean.id);
                                }
                                _draft = _draft.copyWith(
                                  selectedBeanIds: current,
                                );
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Text('Memuat daftar biji...'),
                    error: (_, _) => const Text('Gagal memuat biji.'),
                  ),
                  const SizedBox(height: AppSpacing.s20),

                  // Skor Minimal
                  Text('Skor Minimal', style: textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: [
                      AppChip(
                        label: 'Semua skor',
                        selected: _draft.minScore == null,
                        onSelected: (_) {
                          setState(() {
                            _draft = _draft.copyWith(minScore: null);
                          });
                        },
                      ),
                      ...[3, 4, 5].map((score) {
                        final selected = _draft.minScore == score;
                        return AppChip(
                          label: '★ $score+',
                          selected: selected,
                          onSelected: (_) {
                            setState(() {
                              _draft = _draft.copyWith(minScore: score);
                            });
                          },
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s20),

                  // Tag Rasa
                  Text('Tag Rasa (memuat salah satu)',
                      style: textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: RoasteryNoteTag.values.map((tag) {
                      final selected =
                          _draft.selectedTasteTags.contains(tag.databaseValue);
                      return AppChip(
                        label: tag.label,
                        selected: selected,
                        onSelected: (val) {
                          setState(() {
                            final current =
                                Set<String>.of(_draft.selectedTasteTags);
                            if (val) {
                              current.add(tag.databaseValue);
                            } else {
                              current.remove(tag.databaseValue);
                            }
                            _draft =
                                _draft.copyWith(selectedTasteTags: current);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.s20),

                  // Rentang Tanggal
                  Text('Rentang Tanggal', style: textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: DateRangeOption.values.map((option) {
                      final selected = _draft.dateRange == option;
                      return AppChip(
                        label: option.label,
                        selected: selected,
                        onSelected: (_) async {
                          if (option == DateRangeOption.custom) {
                            await _pickCustomDateRange();
                          } else {
                            setState(() {
                              _draft = _draft.copyWith(
                                dateRange: option,
                                customStartDate: null,
                                customEndDate: null,
                              );
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  if (_draft.dateRange == DateRangeOption.custom &&
                      _draft.customStartDate != null &&
                      _draft.customEndDate != null) ...[
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      '${_formatDate(_draft.customStartDate!)} - ${_formatDate(_draft.customEndDate!)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s20),

                  // Sakelar Entri Dibatalkan
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Tampilkan yang dibatalkan',
                      style: textTheme.bodyMedium,
                    ),
                    value: _draft.includeCancelled,
                    onChanged: (val) {
                      setState(() {
                        _draft = _draft.copyWith(includeCancelled: val);
                      });
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Reset',
                      variant: AppButtonVariant.secondary,
                      onPressed: () {
                        setState(() {
                          _draft = const JournalFilter();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: AppButton(
                      label: 'Terapkan',
                      onPressed: () {
                        ref
                            .read(journalFilterProvider.notifier)
                            .setFilter(_draft);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _draft.customStartDate != null &&
              _draft.customEndDate != null
          ? DateTimeRange(
              start: _draft.customStartDate!,
              end: _draft.customEndDate!,
            )
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
    );
    if (picked != null) {
      setState(() {
        _draft = _draft.copyWith(
          dateRange: DateRangeOption.custom,
          customStartDate: picked.start,
          customEndDate: picked.end,
        );
      });
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }
}
