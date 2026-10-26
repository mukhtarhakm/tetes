import '../beans/bean_model.dart';
import '../journal/journal_model.dart';
import 'brew_calculator.dart';
import 'brew_plan.dart';
import 'brew_session_result.dart';
import 'custom_taste_tags.dart';

class AiRecommendation {
  const AiRecommendation({
    required this.plan,
    required this.note,
    required this.usedFallback,
  });

  final BrewPlan plan;
  final String note;
  final bool usedFallback;
}

enum AiPlanField { dose, ratio, temperature, grind, pouring }

class AiPlanChange {
  const AiPlanChange(this.field, this.label, this.before, this.after);

  final AiPlanField field;
  final String label;
  final String before;
  final String after;
}

class AppliedAiSuggestion {
  const AppliedAiSuggestion({
    required this.before,
    required this.recommended,
    required this.note,
    required this.hasHistory,
    this.editedFields = const {},
  });

  final BrewPlan before;
  final BrewPlan recommended;
  final String note;
  final bool hasHistory;
  final Set<AiPlanField> editedFields;

  List<AiPlanChange> get changes =>
      AiBrew.recommendationChanges(before, recommended);

  bool highlights(AiPlanField field) =>
      changes.any((change) => change.field == field) &&
      !editedFields.contains(field);

  AppliedAiSuggestion markEdited(AiPlanField field) => AppliedAiSuggestion(
    before: before,
    recommended: recommended,
    note: note,
    hasHistory: hasHistory,
    editedFields: {...editedFields, field},
  );

  BrewPlan restore() => before;
}

abstract final class AiBrew {
  static List<AiPlanChange> recommendationChanges(
    BrewPlan before,
    BrewPlan after,
  ) => [
    if (before.doseG != after.doseG)
      AiPlanChange(
        AiPlanField.dose,
        'Dosis',
        '${_aiNumber(before.doseG)} g',
        '${_aiNumber(after.doseG)} g',
      ),
    if (before.ratio != after.ratio)
      AiPlanChange(
        AiPlanField.ratio,
        'Rasio',
        '1:${_aiNumber(before.ratio)}',
        '1:${_aiNumber(after.ratio)}',
      ),
    if (before.waterTempC != after.waterTempC)
      AiPlanChange(
        AiPlanField.temperature,
        'Suhu air',
        '${before.waterTempC} °C',
        '${after.waterTempC} °C',
      ),
    if (before.grind != after.grind)
      AiPlanChange(
        AiPlanField.grind,
        'Ukuran gilingan',
        before.grind.label,
        after.grind.label,
      ),
    if (before.pouringCount != after.pouringCount)
      AiPlanChange(
        AiPlanField.pouring,
        'Pouring',
        '${before.pouringCount}',
        '${after.pouringCount}',
      ),
  ];

  static String _aiNumber(double value) =>
      value.toString().replaceFirst(RegExp(r'\.0$'), '');

  static Map<String, Object?> recommendPayload({
    required Bean bean,
    required List<BrewDetailData> history,
    required int pouringCount,
  }) => {
    'bean': _bean(bean),
    'history': history.take(5).map(_historyBrew).toList(),
    'pouring_count': pouringCount,
  };

  static Map<String, Object?> diagnosePayload({
    required Bean bean,
    required BrewSessionResult result,
    required int tasteScore,
    required Iterable<RoasteryNoteTag> tasteTags,
    Iterable<String> customTasteTags = const [],
    required List<double?> actualWaterG,
    required List<BrewDetailData> history,
    int? drawdownS,
    String? notes,
  }) {
    final plan = result.plan;
    if (actualWaterG.length != plan.stages.length) {
      throw const FormatException('Jumlah air aktual tidak sesuai tahap.');
    }
    return {
      'bean': _bean(bean),
      'brew': {
        'dose_g': plan.doseG,
        'ratio': plan.ratio,
        'water_temp_c': plan.waterTempC,
        'grind': plan.grind.databaseValue,
        'total_time_s': result.totalTimeS,
        'taste_score': tasteScore,
        'taste_tags': tasteTags.map((tag) => tag.databaseValue).join(','),
        'custom_taste_tags': normalizeCustomTasteTags(customTasteTags),
        'notes': _short(notes),
        'stages': [
          for (var index = 0; index < plan.stages.length; index++)
            {
              'position': index + 1,
              'name': plan.stages[index].name.databaseValue,
              'target_start_s': plan.stages[index].startSeconds,
              'target_duration_s': plan.stages[index].durationSeconds,
              'target_water_cum_g': plan.cumulativeWaterAt(index),
              'target_pour_g': plan.stages[index].targetPourG,
              'actual_water_g': actualWaterG[index],
              if (index == plan.stages.length - 1)
                'drawdown_s': drawdownS ?? result.drawdownS,
            },
        ],
      },
      'history': history.take(5).map(_historyBrew).toList(),
    };
  }

  static Map<String, Object?> diagnoseSavedPayload({
    required Bean bean,
    required BrewDetailData detail,
    required List<BrewDetailData> history,
  }) => {
    'bean': _bean(bean),
    'brew': {
      'dose_g': detail.item.doseG,
      'ratio': detail.item.ratio,
      'water_temp_c': detail.item.waterTempC,
      'grind': detail.item.grind.databaseValue,
      'total_time_s': detail.item.totalTimeS,
      'taste_score': detail.item.tasteScore,
      'taste_tags': detail.item.tasteTags.join(','),
      'custom_taste_tags': detail.item.customTasteTags,
      'notes': _short(detail.notes),
      'stages': [
        for (final stage in detail.stages)
          {
            'position': stage.position,
            'name': stage.name.databaseValue,
            'target_start_s': stage.targetStartS,
            'target_duration_s': stage.targetDurationS,
            'target_water_cum_g': stage.targetWaterCumG,
            'target_pour_g': stage.targetPourG,
            'actual_water_g': stage.actualWaterG,
            if (stage.position == detail.stages.length)
              'drawdown_s': stage.drawdownS,
          },
      ],
    },
    'history': history.take(5).map(_historyBrew).toList(),
  };

  static AiRecommendation recommendationFromResponse({
    required BrewPlan fallback,
    required Map<String, dynamic> response,
  }) {
    try {
      if (!_only(response, const [
        'dose_g',
        'ratio',
        'water_temp_c',
        'grind',
        'pouring_count',
        'stages',
        'note',
      ])) {
        throw const FormatException();
      }
      final dose = _number(response['dose_g'], 5, 60);
      final ratio = _number(response['ratio'], 10, 20);
      final temperature = _integer(response['water_temp_c'], 80, 100);
      final grind = response['grind'] is String
          ? Grind.tryFromDatabase(response['grind'] as String)
          : null;
      final note = response['note'];
      final pouringCount = _integer(response['pouring_count'], 1, 5);
      final rows = response['stages'];
      if (dose == null ||
          ratio == null ||
          temperature == null ||
          grind == null ||
          !_text(note) ||
          pouringCount == null ||
          rows is! List ||
          rows.length != pouringCount) {
        throw const FormatException();
      }
      final stages = <BrewStage>[];
      var cumulative = 0.0;
      var previousEnd = 0;
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        if (row is! Map<String, dynamic> ||
            !_only(row, const [
              'name',
              'start_s',
              'duration_s',
              'water_cum_g',
            ]) ||
            row['name'] != BrewStageName.forPosition(index + 1).databaseValue) {
          throw const FormatException();
        }
        final start = _integer(row['start_s'], previousEnd, 3600);
        final duration = _integer(row['duration_s'], 1, 3600);
        final water = _number(row['water_cum_g'], 0, 1200);
        if (start == null ||
            duration == null ||
            water == null ||
            water <= cumulative) {
          throw const FormatException();
        }
        stages.add(
          BrewStage(
            position: index + 1,
            name: BrewStageName.forPosition(index + 1),
            startSeconds: start,
            durationSeconds: duration,
            targetPourG: water - cumulative,
          ),
        );
        cumulative = water;
        previousEnd = start + duration;
      }
      if ((cumulative - dose * ratio).abs() > 1) {
        throw const FormatException();
      }
      final plan = BrewPlan(
        beanId: fallback.beanId,
        doseG: dose,
        ratio: ratio,
        waterTempC: temperature,
        grind: grind,
        pouringCount: stages.length,
        stages: List.unmodifiable(stages),
      );
      BrewCalculator.validatePlan(plan);
      return AiRecommendation(
        plan: plan,
        note: note as String,
        usedFallback: false,
      );
    } catch (_) {
      return fallbackRecommendation(fallback);
    }
  }

  static AiRecommendation fallbackRecommendation(
    BrewPlan fallback, {
    String reason = 'Saran AI tidak dapat dipakai.',
  }) => AiRecommendation(
    plan: fallback,
    note:
        '$reason ${fallback.fromBestBrew ? 'Menggunakan pengaturan seduhan terbaik.' : 'Menggunakan pengaturan awal.'}',
    usedFallback: true,
  );

  static bool validDiagnosis(Map<String, dynamic> value) {
    if (!_only(value, const [
          'diagnosis',
          'likely_causes',
          'suggestions',
          'note',
        ]) ||
        !_text(value['diagnosis']) ||
        !_text(value['note'])) {
      return false;
    }
    final causes = value['likely_causes'];
    final suggestions = value['suggestions'];
    if (causes is! List ||
        causes.isEmpty ||
        causes.length > 5 ||
        causes.any((item) => !_text(item)) ||
        suggestions is! List ||
        suggestions.length > 2) {
      return false;
    }
    for (final item in suggestions) {
      if (item is! Map<String, dynamic> ||
          !_only(item, const ['variable', 'from', 'to', 'reason']) ||
          !_text(item['reason'])) {
        return false;
      }
      switch (item['variable']) {
        case 'dose_g':
          if (_number(item['from'], 5, 60) == null ||
              _number(item['to'], 5, 60) == null) {
            return false;
          }
        case 'ratio':
          if (_number(item['from'], 10, 20) == null ||
              _number(item['to'], 10, 20) == null) {
            return false;
          }
        case 'water_temp_c':
          if (_integer(item['from'], 80, 100) == null ||
              _integer(item['to'], 80, 100) == null) {
            return false;
          }
        case 'grind':
          if (item['from'] is! String ||
              item['to'] is! String ||
              Grind.tryFromDatabase(item['from'] as String) == null ||
              Grind.tryFromDatabase(item['to'] as String) == null) {
            return false;
          }
        default:
          return false;
      }
    }
    return true;
  }

  static Map<String, dynamic> fallbackDiagnosis({
    required BrewPlan plan,
    required int tasteScore,
    required List<String> tasteTags,
  }) {
    String diagnosis;
    String cause;
    Map<String, dynamic>? suggestion;
    if (tasteScore <= 3 && tasteTags.contains('asam')) {
      diagnosis = 'Rasa asam mungkin terkait ekstraksi yang belum cukup.';
      cause = 'Suhu air atau ukuran gilingan mungkin membatasi ekstraksi.';
      suggestion = plan.waterTempC < 100
          ? _suggestion(
              'water_temp_c',
              plan.waterTempC,
              plan.waterTempC + 1,
              'Naikkan suhu sedikit dan bandingkan hasilnya.',
            )
          : _grindSuggestion(plan.grind, finer: true);
    } else if (tasteScore <= 3 && tasteTags.contains('pahit')) {
      diagnosis = 'Rasa pahit mungkin terkait ekstraksi yang terlalu kuat.';
      cause =
          'Suhu air atau ukuran gilingan mungkin terlalu tinggi untuk biji ini.';
      suggestion = plan.waterTempC > 80
          ? _suggestion(
              'water_temp_c',
              plan.waterTempC,
              plan.waterTempC - 1,
              'Turunkan suhu sedikit dan bandingkan hasilnya.',
            )
          : _grindSuggestion(plan.grind, finer: false);
    } else if (tasteTags.contains('hambar')) {
      diagnosis = 'Rasa hambar mungkin memerlukan seduhan yang lebih pekat.';
      cause = 'Rasio air terhadap kopi mungkin terlalu besar.';
      suggestion = plan.ratio > 10
          ? _suggestion(
              'ratio',
              plan.ratio,
              (plan.ratio - 1).clamp(10, 20).toDouble(),
              'Kurangi rasio satu angka dan catat perubahan rasa.',
            )
          : null;
    } else {
      diagnosis =
          'Pengaturan saat ini dapat menjadi titik awal percobaan berikutnya.';
      cause = 'Perbedaan rasa mungkin berasal dari satu pengaturan kecil.';
      final next = plan.waterTempC < 100
          ? plan.waterTempC + 1
          : plan.waterTempC - 1;
      suggestion = _suggestion(
        'water_temp_c',
        plan.waterTempC,
        next,
        'Ubah satu derajat saja agar hasil mudah dibandingkan.',
      );
    }
    return {
      'diagnosis': diagnosis,
      'likely_causes': [cause],
      'suggestions': [?suggestion],
      'note':
          'Saran cadangan tanpa AI. Saran, bukan kepastian. Coba dan catat hasilnya.',
    };
  }

  static BrewPlan? planFromDiagnosis({
    required BrewPlan base,
    required Map<String, dynamic> diagnosis,
  }) {
    if (!validDiagnosis(diagnosis)) return null;
    final suggestions = diagnosis['suggestions'] as List;
    if (suggestions.isEmpty) return null;
    var dose = base.doseG;
    var ratio = base.ratio;
    var temperature = base.waterTempC;
    var grind = base.grind;
    final seen = <String>{};
    for (final raw in suggestions) {
      final item = raw as Map<String, dynamic>;
      final variable = item['variable'] as String;
      if (!seen.add(variable)) return null;
      switch (variable) {
        case 'dose_g':
          if (item['from'] != base.doseG) return null;
          dose = (item['to'] as num).toDouble();
        case 'ratio':
          if (item['from'] != base.ratio) return null;
          ratio = (item['to'] as num).toDouble();
        case 'water_temp_c':
          if (item['from'] != base.waterTempC) return null;
          temperature = item['to'] as int;
        case 'grind':
          if (item['from'] != base.grind.databaseValue) return null;
          grind = Grind.tryFromDatabase(item['to'] as String)!;
      }
    }
    try {
      final plan = BrewCalculator.createDefault(
        beanId: base.beanId,
        doseG: dose,
        ratio: ratio,
        waterTempC: temperature,
        grind: grind,
        pouringCount: base.pouringCount,
      );
      BrewCalculator.validatePlan(plan);
      return plan;
    } catch (_) {
      return null;
    }
  }

  static String diagnosisSummary(Map<String, dynamic> value) {
    if (!validDiagnosis(value)) return 'Saran AI tidak dapat ditampilkan.';
    final causes = (value['likely_causes'] as List).cast<String>();
    final suggestions = (value['suggestions'] as List)
        .cast<Map<String, dynamic>>();
    return [
      value['diagnosis'] as String,
      'Kemungkinan penyebab: ${causes.join('; ')}',
      if (suggestions.isNotEmpty)
        'Saran: ${suggestions.map((item) => '${_variableLabel(item['variable'] as String)}: ${item['from']} → ${item['to']} (${item['reason']})').join('; ')}',
      value['note'] as String,
    ].join('\n');
  }

  static Map<String, Object?> _bean(Bean bean) {
    final value = <String, Object?>{
      'name': bean.name,
      'species': bean.species.databaseValue,
      'is_self_roasted': bean.isSelfRoasted,
      'initial_stock_g': bean.initialStockG,
    };
    if (bean.beanType != null) {
      value['bean_type'] = bean.beanType!.databaseValue;
    }
    if (bean.arabicaPercent != null) {
      value['arabica_percent'] = bean.arabicaPercent;
    }
    _addText(value, 'roastery', bean.roastery);
    _addText(value, 'origin', bean.origin);
    if (bean.process != null) value['process'] = bean.process!.databaseValue;
    _addText(value, 'process_custom', bean.processCustom);
    if (bean.roastLevel != null) {
      value['roast_level'] = bean.roastLevel!.databaseValue;
    }
    if (bean.roastDate != null) value['roast_date'] = bean.roastDate;
    if (bean.roasteryNotesTags.isNotEmpty) {
      value['roastery_notes_tags'] = bean.roasteryNotesTags.join(',');
    }
    _addText(value, 'roastery_notes_text', _short(bean.roasteryNotesText));
    return value;
  }

  static Map<String, Object?> _historyBrew(BrewDetailData detail) {
    final brew = detail.item;
    return {
      'dose_g': brew.doseG,
      'ratio': brew.ratio,
      'water_temp_c': brew.waterTempC,
      'grind': brew.grind.databaseValue,
      'total_time_s': brew.totalTimeS,
      'taste_score': brew.tasteScore,
      'taste_tags': brew.tasteTags.join(','),
      'brewed_at_utc': brew.brewedAtUtc,
      'status': brew.status,
      'notes': _short(detail.notes),
    };
  }

  static void _addText(Map<String, Object?> value, String key, String? text) {
    if (text != null && text.trim().isNotEmpty) value[key] = text;
  }

  static String? _short(String? text) =>
      text == null ? null : String.fromCharCodes(text.runes.take(500));

  static bool _only(Map<String, dynamic> value, List<String> keys) =>
      value.length == keys.length && keys.every(value.containsKey);

  static double? _number(Object? value, num min, num max) =>
      value is num && value.isFinite && value >= min && value <= max
      ? value.toDouble()
      : null;

  static int? _integer(Object? value, int min, int max) =>
      value is int && value >= min && value <= max ? value : null;

  static bool _text(Object? value) =>
      value is String && value.trim().isNotEmpty && value.length <= 500;

  static Map<String, dynamic> _suggestion(
    String variable,
    Object from,
    Object to,
    String reason,
  ) => {'variable': variable, 'from': from, 'to': to, 'reason': reason};

  static Map<String, dynamic>? _grindSuggestion(
    Grind grind, {
    required bool finer,
  }) {
    final next = grind.index + (finer ? -1 : 1);
    if (next < 0 || next >= Grind.values.length) return null;
    return _suggestion(
      'grind',
      grind.databaseValue,
      Grind.values[next].databaseValue,
      finer
          ? 'Coba satu tingkat lebih halus.'
          : 'Coba satu tingkat lebih kasar.',
    );
  }

  static String _variableLabel(String variable) => switch (variable) {
    'dose_g' => 'Dosis',
    'ratio' => 'Rasio',
    'water_temp_c' => 'Suhu air',
    _ => 'Gilingan',
  };
}
