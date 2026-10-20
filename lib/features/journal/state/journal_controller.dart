import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/state/session_controller.dart';
import '../../brew/state/brew_setup_controller.dart';
import '../journal_model.dart';

final journalFilterProvider =
    NotifierProvider<JournalFilterNotifier, JournalFilter>(
      JournalFilterNotifier.new,
    );

class JournalFilterNotifier extends Notifier<JournalFilter> {
  @override
  JournalFilter build() => const JournalFilter();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleBean(String beanId) {
    final current = Set<String>.of(state.selectedBeanIds);
    if (current.contains(beanId)) {
      current.remove(beanId);
    } else {
      current.add(beanId);
    }
    state = state.copyWith(selectedBeanIds: current);
  }

  void setMinScore(int? score) {
    state = state.copyWith(minScore: score);
  }

  void toggleTasteTag(String tag) {
    final current = Set<String>.of(state.selectedTasteTags);
    if (current.contains(tag)) {
      current.remove(tag);
    } else {
      current.add(tag);
    }
    state = state.copyWith(selectedTasteTags: current);
  }

  void setDateRange(
    DateRangeOption option, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    state = state.copyWith(
      dateRange: option,
      customStartDate: customStart,
      customEndDate: customEnd,
    );
  }

  void setSortOption(BrewSortOption sortOption) {
    state = state.copyWith(sortOption: sortOption);
  }

  void setIncludeCancelled(bool include) {
    state = state.copyWith(includeCancelled: include);
  }

  void setFilter(JournalFilter filter) {
    state = filter;
  }

  void reset() {
    state = const JournalFilter();
  }
}

(String? startUtc, String? endUtc) calculateUtcDateBounds(JournalFilter filter) {
  final now = DateTime.now();
  switch (filter.dateRange) {
    case DateRangeOption.all:
      return (null, null);
    case DateRangeOption.sevenDays:
      final startLocal = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      final endLocal = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return (_toUtcIso(startLocal), _toUtcIso(endLocal));
    case DateRangeOption.thirtyDays:
      final startLocal = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 29));
      final endLocal = DateTime(now.year, now.month, now.day, 23, 59, 59);
      return (_toUtcIso(startLocal), _toUtcIso(endLocal));
    case DateRangeOption.custom:
      if (filter.customStartDate == null && filter.customEndDate == null) {
        return (null, null);
      }
      final startLocal = filter.customStartDate != null
          ? DateTime(
              filter.customStartDate!.year,
              filter.customStartDate!.month,
              filter.customStartDate!.day,
              0,
              0,
              0,
            )
          : null;
      final endLocal = filter.customEndDate != null
          ? DateTime(
              filter.customEndDate!.year,
              filter.customEndDate!.month,
              filter.customEndDate!.day,
              23,
              59,
              59,
            )
          : null;
      return (
        startLocal != null ? _toUtcIso(startLocal) : null,
        endLocal != null ? _toUtcIso(endLocal) : null,
      );
  }
}

String _toUtcIso(DateTime dt) {
  return dt.toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');
}

final journalBrewsProvider = FutureProvider<List<BrewJournalItem>>((ref) async {
  final session = await ref.watch(sessionControllerProvider.future);
  final userId = session.userId;
  if (session.status != SessionStatus.authenticated || userId == null) {
    return const [];
  }
  final filter = ref.watch(journalFilterProvider);
  final repo = await ref.watch(brewRepositoryProvider.future);
  final (startUtc, endUtc) = calculateUtcDateBounds(filter);

  return repo.findJournalBrews(
    userId: userId,
    searchQuery: filter.searchQuery,
    beanIds: filter.selectedBeanIds.isEmpty ? null : filter.selectedBeanIds,
    minTasteScore: filter.minScore,
    tasteTags: filter.selectedTasteTags.isEmpty ? null : filter.selectedTasteTags,
    startBrewedAtUtc: startUtc,
    endBrewedAtUtc: endUtc,
    sortOption: filter.sortOption,
    includeCancelled: filter.includeCancelled,
  );
});

final brewDetailProvider =
    FutureProvider.family<BrewDetailData?, String>((ref, brewId) async {
      final session = await ref.watch(sessionControllerProvider.future);
      final userId = session.userId;
      if (session.status != SessionStatus.authenticated || userId == null) {
        return null;
      }
      final repo = await ref.watch(brewRepositoryProvider.future);
      return repo.findBrewDetail(userId: userId, brewId: brewId);
    });
