import '../brew/brew_calculator.dart';
import '../brew/brew_plan.dart';

enum BrewSortOption {
  newest('Terbaru'),
  highestScore('Skor tertinggi'),
  cost('Biaya');

  const BrewSortOption(this.label);
  final String label;
}

enum DateRangeOption {
  all('Semua'),
  sevenDays('7 hari'),
  thirtyDays('30 hari'),
  custom('Kustom');

  const DateRangeOption(this.label);
  final String label;
}

class BrewJournalItem {
  const BrewJournalItem({
    required this.id,
    required this.userId,
    required this.seq,
    required this.beanId,
    required this.beanName,
    this.beanRoastery,
    required this.isBestBrew,
    required this.brewedAtUtc,
    required this.doseG,
    required this.ratio,
    required this.waterTempC,
    required this.grind,
    required this.totalTimeS,
    required this.tasteScore,
    required this.tasteTags,
    this.customTasteTags = const [],
    this.costIdr,
    required this.status,
    required this.syncStatus,
    required this.hash,
  });

  final String id;
  final String userId;
  final int seq;
  final String beanId;
  final String beanName;
  final String? beanRoastery;
  final bool isBestBrew;
  final String brewedAtUtc;
  final double doseG;
  final double ratio;
  final int waterTempC;
  final Grind grind;
  final int totalTimeS;
  final int tasteScore;
  final List<String> tasteTags;
  final List<String> customTasteTags;
  final double? costIdr;
  final String status;
  final String syncStatus;
  final String hash;

  bool get isCancelled => status == 'dibatalkan';
}

class BrewDetailStage {
  const BrewDetailStage({
    required this.id,
    required this.brewId,
    required this.position,
    required this.name,
    required this.targetStartS,
    required this.targetDurationS,
    required this.targetWaterCumG,
    required this.targetPourG,
    this.actualWaterG,
    this.drawdownS,
  });

  final String id;
  final String brewId;
  final int position;
  final BrewStageName name;
  final int targetStartS;
  final int targetDurationS;
  final double targetWaterCumG;
  final double targetPourG;
  final double? actualWaterG;
  final int? drawdownS;
}

class BrewDetailData {
  const BrewDetailData({
    required this.item,
    this.notes,
    this.aiAdvice,
    required this.prevHash,
    required this.createdAt,
    required this.roasteryNotesTags,
    this.roasteryNotesText,
    required this.isBeanArchived,
    required this.stages,
  });

  final BrewJournalItem item;
  final String? notes;
  final String? aiAdvice;
  final String prevHash;
  final String createdAt;
  final List<String> roasteryNotesTags;
  final String? roasteryNotesText;
  final bool isBeanArchived;
  final List<BrewDetailStage> stages;

  int? get finalDrawdownS {
    if (stages.isEmpty) return null;
    return stages.last.drawdownS;
  }

  BrewPlan? toBrewPlan() {
    if (isBeanArchived) return null;
    if (stages.isEmpty || stages.length > 5) return null;
    final planStages = <BrewStage>[];
    var cumulativeWater = 0.0;
    for (final stage in stages) {
      cumulativeWater += stage.targetPourG;
      if ((stage.targetWaterCumG - cumulativeWater).abs() > 0.000001) {
        return null;
      }
      planStages.add(
        BrewStage(
          position: stage.position,
          name: stage.name,
          startSeconds: stage.targetStartS,
          durationSeconds: stage.targetDurationS,
          targetPourG: stage.targetPourG,
        ),
      );
    }
    try {
      final plan = BrewPlan(
        beanId: item.beanId,
        doseG: item.doseG,
        ratio: item.ratio,
        waterTempC: item.waterTempC,
        grind: item.grind,
        pouringCount: planStages.length,
        stages: List.unmodifiable(planStages),
        fromBestBrew: item.isBestBrew,
      );
      BrewCalculator.validatePlan(plan);
      return plan;
    } catch (_) {
      return null;
    }
  }
}

class JournalFilter {
  const JournalFilter({
    this.searchQuery = '',
    this.selectedBeanIds = const {},
    this.minScore,
    this.selectedTasteTags = const {},
    this.dateRange = DateRangeOption.all,
    this.customStartDate,
    this.customEndDate,
    this.sortOption = BrewSortOption.newest,
    this.includeCancelled = false,
  });

  final String searchQuery;
  final Set<String> selectedBeanIds;
  final int? minScore;
  final Set<String> selectedTasteTags;
  final DateRangeOption dateRange;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final BrewSortOption sortOption;
  final bool includeCancelled;

  bool get isFiltered =>
      searchQuery.trim().isNotEmpty ||
      selectedBeanIds.isNotEmpty ||
      minScore != null ||
      selectedTasteTags.isNotEmpty ||
      dateRange != DateRangeOption.all ||
      includeCancelled ||
      sortOption != BrewSortOption.newest;

  JournalFilter copyWith({
    String? searchQuery,
    Set<String>? selectedBeanIds,
    Object? minScore = _unset,
    Set<String>? selectedTasteTags,
    DateRangeOption? dateRange,
    Object? customStartDate = _unset,
    Object? customEndDate = _unset,
    BrewSortOption? sortOption,
    bool? includeCancelled,
  }) {
    return JournalFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedBeanIds: selectedBeanIds ?? this.selectedBeanIds,
      minScore: identical(minScore, _unset) ? this.minScore : minScore as int?,
      selectedTasteTags: selectedTasteTags ?? this.selectedTasteTags,
      dateRange: dateRange ?? this.dateRange,
      customStartDate: identical(customStartDate, _unset)
          ? this.customStartDate
          : customStartDate as DateTime?,
      customEndDate: identical(customEndDate, _unset)
          ? this.customEndDate
          : customEndDate as DateTime?,
      sortOption: sortOption ?? this.sortOption,
      includeCancelled: includeCancelled ?? this.includeCancelled,
    );
  }

  JournalFilter reset() => const JournalFilter();
}

const _unset = Object();
