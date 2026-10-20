enum BeanSpecies {
  arabika('arabika', 'Arabika'),
  robusta('robusta', 'Robusta'),
  campuran('campuran', 'Campuran');

  const BeanSpecies(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static BeanSpecies fromDatabase(String value) {
    return values.firstWhere((item) => item.databaseValue == value);
  }
}

enum BeanType {
  singleOrigin('single_origin', 'Single origin'),
  blend('blend', 'Blend');

  const BeanType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static BeanType? fromDatabase(String? value) {
    if (value == null) {
      return null;
    }
    return values.firstWhere((item) => item.databaseValue == value);
  }
}

enum BeanProcess {
  washed('washed', 'Washed'),
  natural('natural', 'Natural'),
  honey('honey', 'Honey'),
  lainnya('lainnya', 'Lainnya');

  const BeanProcess(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static BeanProcess? fromDatabase(String? value) {
    if (value == null) {
      return null;
    }
    return values.firstWhere((item) => item.databaseValue == value);
  }
}

enum RoastLevel {
  light('light', 'Light'),
  medium('medium', 'Medium'),
  dark('dark', 'Dark');

  const RoastLevel(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static RoastLevel? fromDatabase(String? value) {
    if (value == null) {
      return null;
    }
    return values.firstWhere((item) => item.databaseValue == value);
  }
}

enum RoasteryNoteTag {
  asam('asam', 'Asam'),
  pahit('pahit', 'Pahit'),
  hambar('hambar', 'Hambar'),
  seimbang('seimbang', 'Seimbang'),
  manis('manis', 'Manis'),
  cokelat('cokelat', 'Cokelat'),
  buah('buah', 'Buah'),
  kacang('kacang', 'Kacang'),
  floral('floral', 'Floral'),
  karamel('karamel', 'Karamel'),
  rempah('rempah', 'Rempah');

  const RoasteryNoteTag(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static String labelForValue(String value) {
    for (final tag in values) {
      if (tag.databaseValue == value) {
        return tag.label;
      }
    }
    return value;
  }

  static bool isBuiltIn(String value) {
    return values.any((tag) => tag.databaseValue == value);
  }
}

abstract final class BeanTagValues {
  static List<String> fromDatabase(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const [];
    }
    final tags = value
        .split(',')
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    tags.sort();
    return tags;
  }
}

abstract final class BeanDefaults {
  static const lowStockThresholdG = 15.0;
  static const selfRoasteryName = 'Roasting sendiri';
}

class Bean {
  const Bean({
    required this.id,
    required this.userId,
    required this.name,
    required this.species,
    required this.isSelfRoasted,
    required this.initialStockG,
    required this.remainingStockG,
    required this.roasteryNotesTags,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
    required this.syncStatus,
    required this.brewCount,
    this.beanType,
    this.arabicaPercent,
    this.roastery,
    this.origin,
    this.process,
    this.processCustom,
    this.roastLevel,
    this.roastDate,
    this.packSizeG,
    this.priceOriginal,
    this.currency,
    this.fxRate,
    this.fxDate,
    this.priceIdrPerKg,
    this.roasteryNotesText,
    this.bestBrewId,
    this.bestBrewRatio,
    this.bestBrewWaterTempC,
    this.bestBrewTasteScore,
    this.lowStockThresholdG = BeanDefaults.lowStockThresholdG,
  });

  final String id;
  final String userId;
  final String name;
  final BeanSpecies species;
  final BeanType? beanType;
  final int? arabicaPercent;
  final String? roastery;
  final bool isSelfRoasted;
  final String? origin;
  final BeanProcess? process;
  final String? processCustom;
  final RoastLevel? roastLevel;
  final String? roastDate;
  final double? packSizeG;
  final double? priceOriginal;
  final String? currency;
  final double? fxRate;
  final String? fxDate;
  final double? priceIdrPerKg;
  final double initialStockG;
  final double remainingStockG;
  final List<String> roasteryNotesTags;
  final String? roasteryNotesText;
  final String? bestBrewId;
  final double? bestBrewRatio;
  final int? bestBrewWaterTempC;
  final int? bestBrewTasteScore;
  final double lowStockThresholdG;
  final bool archived;
  final String createdAt;
  final String updatedAt;
  final String syncStatus;
  final int brewCount;

  bool get isLowStock => remainingStockG < lowStockThresholdG;

  String? get bestBrewSummary {
    if (bestBrewRatio == null ||
        bestBrewWaterTempC == null ||
        bestBrewTasteScore == null) {
      return null;
    }
    final ratioText = bestBrewRatio! % 1 == 0
        ? '1:${bestBrewRatio!.toInt()}'
        : '1:${bestBrewRatio!.toStringAsFixed(1)}';
    return 'Terbaik: $ratioText • $bestBrewWaterTempC°C • ★ $bestBrewTasteScore/5';
  }

  factory Bean.fromMap(Map<String, Object?> map) {
    return Bean(
      id: map['id']! as String,
      userId: map['user_id']! as String,
      name: map['name']! as String,
      species: BeanSpecies.fromDatabase(map['species']! as String),
      beanType: BeanType.fromDatabase(map['bean_type'] as String?),
      arabicaPercent: (map['arabica_percent'] as num?)?.toInt(),
      roastery: map['roastery'] as String?,
      isSelfRoasted: map['is_self_roasted'] == 1,
      origin: map['origin'] as String?,
      process: BeanProcess.fromDatabase(map['process'] as String?),
      processCustom: map['process_custom'] as String?,
      roastLevel: RoastLevel.fromDatabase(map['roast_level'] as String?),
      roastDate: map['roast_date'] as String?,
      packSizeG: (map['pack_size_g'] as num?)?.toDouble(),
      priceOriginal: (map['price_original'] as num?)?.toDouble(),
      currency: map['currency'] as String?,
      fxRate: (map['fx_rate'] as num?)?.toDouble(),
      fxDate: map['fx_date'] as String?,
      priceIdrPerKg: (map['price_idr_per_kg'] as num?)?.toDouble(),
      initialStockG: (map['initial_stock_g']! as num).toDouble(),
      remainingStockG: (map['remaining_stock_g']! as num).toDouble(),
      roasteryNotesTags: BeanTagValues.fromDatabase(
        map['roastery_notes_tags'] as String?,
      ),
      roasteryNotesText: map['roastery_notes_text'] as String?,
      bestBrewId: map['best_brew_id'] as String?,
      bestBrewRatio: (map['best_brew_ratio'] as num?)?.toDouble(),
      bestBrewWaterTempC: (map['best_brew_water_temp_c'] as num?)?.toInt(),
      bestBrewTasteScore: (map['best_brew_taste_score'] as num?)?.toInt(),
      lowStockThresholdG: (map['low_stock_threshold_g'] as num?)?.toDouble() ??
          BeanDefaults.lowStockThresholdG,
      archived: map['archived'] == 1,
      createdAt: map['created_at']! as String,
      updatedAt: map['updated_at']! as String,
      syncStatus: map['sync_status']! as String,
      brewCount: (map['brew_count']! as num).toInt(),
    );
  }
}

class BeanDraft {
  const BeanDraft({
    required this.name,
    required this.species,
    required this.isSelfRoasted,
    required this.initialStockG,
    required this.roasteryNotesTags,
    this.beanType,
    this.arabicaPercent,
    this.roastery,
    this.origin,
    this.process,
    this.processCustom,
    this.roastLevel,
    this.roastDate,
    this.packSizeG,
    this.priceOriginal,
    this.currency,
    this.fxRate,
    this.fxDate,
    this.priceIdrPerKg,
    this.roasteryNotesText,
  });

  final String name;
  final BeanSpecies species;
  final BeanType? beanType;
  final int? arabicaPercent;
  final String? roastery;
  final bool isSelfRoasted;
  final String? origin;
  final BeanProcess? process;
  final String? processCustom;
  final RoastLevel? roastLevel;
  final String? roastDate;
  final double? packSizeG;
  final double? priceOriginal;
  final String? currency;
  final double? fxRate;
  final String? fxDate;
  final double? priceIdrPerKg;
  final double initialStockG;
  final List<String> roasteryNotesTags;
  final String? roasteryNotesText;
}
