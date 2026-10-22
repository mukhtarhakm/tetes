import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_dropdown_field.dart';
import '../../../core/ui/app_input_dialog.dart';
import '../../../core/ui/app_text_field.dart';
import '../bean_model.dart';
import '../bean_validation.dart';
import '../fx_conversion.dart';
import '../fx_quote_service.dart';
import '../state/bean_providers.dart';

class BeanFormScreen extends ConsumerStatefulWidget {
  const BeanFormScreen({this.initialBean, super.key});

  final Bean? initialBean;

  @override
  ConsumerState<BeanFormScreen> createState() => _BeanFormScreenState();
}

class _BeanFormScreenState extends ConsumerState<BeanFormScreen> {
  static const _currencies = ['IDR', 'USD', 'EUR', 'JPY'];
  static const _standardPackSizes = [100.0, 150.0, 200.0, 250.0, 500.0, 1000.0];

  late final TextEditingController _nameController;
  late final TextEditingController _originController;
  late final TextEditingController _roasteryController;
  late final TextEditingController _processCustomController;
  late final TextEditingController _customPackController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _notesController;

  BeanSpecies? _species;
  BeanType? _beanType;
  BeanProcess? _process;
  RoastLevel? _roastLevel;
  int? _arabicaPercent;
  bool _isSelfRoasted = false;
  String? _roastDate;
  double? _packSizeG;
  bool _customPackSelected = false;
  bool _stockEditedManually = false;
  String? _currency;
  Set<String> _selectedTags = {};
  Map<String, String> _errors = const {};
  final FxRequestGuard _fxRequestGuard = FxRequestGuard();
  Timer? _fxDebounce;
  FxPricingInput? _originalPricingInput;
  FxQuote? _fxQuote;
  double? _priceIdrPerPackage;
  double? _priceIdrPerKg;
  bool _isFxLoading = false;
  String? _fxMessage;

  @override
  void initState() {
    super.initState();
    final bean = widget.initialBean;
    final existingPackSize = bean?.packSizeG;
    final hasStandardPack =
        existingPackSize != null &&
        _standardPackSizes.contains(existingPackSize);
    _nameController = TextEditingController(text: bean?.name);
    _originController = TextEditingController(text: bean?.origin);
    _roasteryController = TextEditingController(text: bean?.roastery);
    _processCustomController = TextEditingController(text: bean?.processCustom);
    _customPackController = TextEditingController(
      text: existingPackSize != null && !hasStandardPack
          ? _formatEditableNumber(existingPackSize)
          : null,
    );
    _priceController = TextEditingController(
      text: bean?.priceOriginal == null
          ? null
          : _formatEditableNumber(bean!.priceOriginal!),
    );
    _stockController = TextEditingController(
      text: bean == null ? null : _formatEditableNumber(bean.initialStockG),
    );
    _notesController = TextEditingController(text: bean?.roasteryNotesText);
    _species = bean?.species;
    _beanType = bean?.beanType;
    _process = bean?.process;
    _roastLevel = bean?.roastLevel;
    _arabicaPercent = bean?.arabicaPercent;
    _isSelfRoasted = bean?.isSelfRoasted ?? false;
    _roastDate = bean?.roastDate;
    _packSizeG = hasStandardPack ? existingPackSize : null;
    _customPackSelected = existingPackSize != null && !hasStandardPack;
    _stockEditedManually = bean != null;
    _currency = bean?.currency;
    _selectedTags = {...?bean?.roasteryNotesTags};
    _originalPricingInput = FxPricingInput(
      priceOriginal: bean?.priceOriginal,
      currency: bean?.currency,
      packSizeG: bean?.packSizeG,
    );
    _restoreOriginalFx();
  }

  @override
  void dispose() {
    _fxDebounce?.cancel();
    _nameController.dispose();
    _originController.dispose();
    _roasteryController.dispose();
    _processCustomController.dispose();
    _customPackController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mutation = ref.watch(beanMutationProvider);
    final isSaving = mutation.isLoading;
    final sortedBuiltInTags = [...RoasteryNoteTag.values]
      ..sort((left, right) => left.label.compareTo(right.label));
    final customTags =
        _selectedTags.where((tag) => !RoasteryNoteTag.isBuiltIn(tag)).toList()
          ..sort();
    final tagLimitReached =
        _selectedTags.length >= BeanValidation.maximumTagCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialBean == null ? 'Tambah biji' : 'Ubah biji'),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: AppInsets.screen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Info biji', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.s12),
              AppTextField(
                controller: _nameController,
                label: 'Nama biji',
                errorText: _errors['name'],
                enabled: !isSaving,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearError('name'),
              ),
              const SizedBox(height: AppSpacing.s20),
              AppTextField(
                controller: _originController,
                label: 'Asal (negara atau daerah)',
                enabled: !isSaving,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.s20),
              AppTextField(
                controller: _roasteryController,
                label: 'Roastery',
                enabled: !isSaving && !_isSelfRoasted,
                textInputAction: TextInputAction.next,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Roasting sendiri',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                value: _isSelfRoasted,
                onChanged: isSaving ? null : _toggleSelfRoasted,
              ),
              const SizedBox(height: AppSpacing.s20),
              _SectionLabel(label: 'Spesies', errorText: _errors['species']),
              const SizedBox(height: AppSpacing.s8),
              _chipWrap(
                BeanSpecies.values
                    .map(
                      (species) => AppChip(
                        label: species.label,
                        selected: _species == species,
                        onSelected: isSaving
                            ? null
                            : (_) => _selectSpecies(species),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.s20),
              const _SectionLabel(label: 'Tipe'),
              const SizedBox(height: AppSpacing.s8),
              _optionalChips<BeanType>(
                values: BeanType.values,
                selected: _beanType,
                label: (value) => value.label,
                enabled: !isSaving,
                onChanged: (value) => setState(() => _beanType = value),
              ),
              if (_species == BeanSpecies.campuran) ...[
                const SizedBox(height: AppSpacing.s20),
                _SectionLabel(
                  label: 'Persen arabika: ${_arabicaPercent ?? 0}%',
                  errorText: _errors['arabicaPercent'],
                ),
                Slider(
                  value: (_arabicaPercent ?? 0).toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '${_arabicaPercent ?? 0}%',
                  onChanged: isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _arabicaPercent = value.round();
                            _errors = Map.of(_errors)..remove('arabicaPercent');
                          });
                        },
                ),
              ],
              const SizedBox(height: AppSpacing.s24),
              Text('Pengolahan', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.s12),
              const _SectionLabel(label: 'Proses'),
              const SizedBox(height: AppSpacing.s8),
              _optionalChips<BeanProcess>(
                values: BeanProcess.values,
                selected: _process,
                label: (value) => value.label,
                enabled: !isSaving,
                onChanged: _selectProcess,
              ),
              if (_process == BeanProcess.lainnya) ...[
                const SizedBox(height: AppSpacing.s16),
                AppTextField(
                  controller: _processCustomController,
                  label: 'Nama proses lainnya',
                  errorText: _errors['processCustom'],
                  enabled: !isSaving,
                  maxLength: BeanValidation.maximumCustomProcessLength,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _clearError('processCustom'),
                ),
              ],
              const SizedBox(height: AppSpacing.s20),
              const _SectionLabel(label: 'Tingkat sangrai'),
              const SizedBox(height: AppSpacing.s8),
              _optionalChips<RoastLevel>(
                values: RoastLevel.values,
                selected: _roastLevel,
                label: (value) => value.label,
                enabled: !isSaving,
                onChanged: (value) => setState(() => _roastLevel = value),
              ),
              const SizedBox(height: AppSpacing.s20),
              AppButton(
                label: _roastDate == null
                    ? 'Pilih tanggal roasting'
                    : 'Tanggal roasting: $_roastDate',
                icon: Icons.calendar_month_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: isSaving ? null : _pickRoastDate,
              ),
              if (_roastDate != null)
                AppButton(
                  label: 'Hapus tanggal roasting',
                  variant: AppButtonVariant.text,
                  onPressed: isSaving
                      ? null
                      : () => setState(() => _roastDate = null),
                ),
              const SizedBox(height: AppSpacing.s24),
              Text('Pembelian', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.s12),
              _SectionLabel(
                label: 'Ukuran kemasan',
                errorText: _errors['packSize'],
              ),
              const SizedBox(height: AppSpacing.s8),
              _chipWrap([
                ..._standardPackSizes.map(
                  (size) => AppChip(
                    label: '${_formatEditableNumber(size)} g',
                    selected: !_customPackSelected && _packSizeG == size,
                    onSelected: isSaving
                        ? null
                        : (selected) => _selectStandardPack(size, selected),
                  ),
                ),
                AppChip(
                  label: 'Lainnya',
                  selected: _customPackSelected,
                  onSelected: isSaving ? null : _selectCustomPack,
                ),
              ]),
              if (_customPackSelected) ...[
                const SizedBox(height: AppSpacing.s16),
                AppTextField(
                  key: const Key('bean-custom-pack-field'),
                  controller: _customPackController,
                  label: 'Ukuran kemasan lainnya (g)',
                  errorText: _errors['packSize'],
                  enabled: !isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: _onCustomPackChanged,
                ),
              ],
              const SizedBox(height: AppSpacing.s20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      controller: _priceController,
                      label: 'Harga kemasan',
                      hintText: 'Opsional',
                      errorText: _errors['price'],
                      enabled: !isSaving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      onChanged: _onPriceChanged,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: AppDropdownField<String>(
                      label: 'Mata uang',
                      items: _currencies,
                      itemLabel: (currency) => currency,
                      value: _currency,
                      errorText: _errors['currency'],
                      enabled: !isSaving,
                      onChanged: (currency) {
                        setState(() {
                          _currency = currency;
                          _errors = Map.of(_errors)..remove('currency');
                        });
                        _scheduleFxUpdate(immediate: true);
                      },
                    ),
                  ),
                ],
              ),
              _buildFxResult(context),
              const SizedBox(height: AppSpacing.s20),
              AppTextField(
                key: const Key('bean-stock-field'),
                controller: _stockController,
                label: 'Stok awal (g)',
                errorText: _errors['stock'],
                enabled: !isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  _stockEditedManually = true;
                  _clearError('stock');
                },
              ),
              const SizedBox(height: AppSpacing.s24),
              Text('Rasa', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.s12),
              _SectionLabel(
                label: 'Tasting notes roastery',
                errorText: _errors['tags'],
              ),
              const SizedBox(height: AppSpacing.s8),
              _chipWrap([
                ...sortedBuiltInTags.map((tag) {
                  final selected = _selectedTags.contains(tag.databaseValue);
                  return AppChip(
                    label: tag.label,
                    selected: selected,
                    onSelected: isSaving || (!selected && tagLimitReached)
                        ? null
                        : (value) => _toggleBuiltInTag(tag, value),
                  );
                }),
                AppChip(
                  label: '+ Tambah sendiri',
                  onSelected: isSaving || tagLimitReached
                      ? null
                      : (_) => _addCustomTag(),
                ),
                ...customTags.map(
                  (tag) => AppChip(
                    label: tag,
                    onDeleted: isSaving ? null : () => _removeTag(tag),
                  ),
                ),
              ]),
              if (tagLimitReached) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  'Maksimal ${BeanValidation.maximumTagCount} tag per biji.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
              const SizedBox(height: AppSpacing.s16),
              AppTextField(
                controller: _notesController,
                label: 'Catatan roastery',
                hintText: 'Opsional',
                enabled: !isSaving,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
              if (mutation.hasError) ...[
                const SizedBox(height: AppSpacing.s16),
                Text(
                  'Biji tidak dapat disimpan. Silakan coba lagi.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.s24),
              AppButton(
                label: 'Simpan',
                isLoading: isSaving,
                onPressed: isSaving || _isFxLoading ? null : _submit,
              ),
              const SizedBox(height: AppSpacing.s8),
              AppButton(
                label: 'Batal',
                variant: AppButtonVariant.text,
                onPressed: isSaving ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFxResult(BuildContext context) {
    if (!_isFxLoading && _fxQuote == null && _fxMessage == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s16),
      child: AppCard(
        variant: AppCardVariant.tinted,
        child: _isFxLoading
            ? Row(
                children: [
                  const SizedBox.square(
                    dimension: AppSizes.buttonProgress,
                    child: CircularProgressIndicator(
                      strokeWidth: AppSizes.progressStroke,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      'Mengambil kurs rupiah...',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              )
            : _fxQuote == null
            ? Text(
                _fxMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hasil rupiah',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    '${formatIdr(_priceIdrPerPackage!)} per kemasan',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    '${formatIdr(_priceIdrPerKg!)} per kg',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    _fxDescription(_fxQuote!),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                  ),
                ],
              ),
      ),
    );
  }

  String _fxDescription(FxQuote quote) {
    if (quote.currency == 'IDR') {
      return 'IDR tidak memerlukan konversi.';
    }
    final base = '1 ${quote.currency} = ${formatIdr(quote.rate)}';
    return quote.source == FxQuoteSource.cache
        ? '$base • kurs per ${quote.date}'
        : base;
  }

  void _onPriceChanged(String _) {
    _clearError('price');
    _scheduleFxUpdate();
  }

  void _scheduleFxUpdate({bool immediate = false}) {
    _fxDebounce?.cancel();
    final input = _currentPricingInput;
    if (!FxConversion.shouldRecalculate(
      original: _originalPricingInput,
      current: input,
    )) {
      _fxRequestGuard.invalidate();
      setState(_restoreOriginalFx);
      return;
    }
    if (!input.isComplete) {
      _fxRequestGuard.invalidate();
      setState(_clearFx);
      return;
    }

    final generation = _fxRequestGuard.issue(input);
    setState(() {
      _isFxLoading = true;
      _fxMessage = null;
      _fxQuote = null;
      _priceIdrPerPackage = null;
      _priceIdrPerKg = null;
    });
    if (immediate) {
      unawaited(_loadFx(input, generation));
      return;
    }
    _fxDebounce = Timer(
      AppConfig.fxInputDebounce,
      () => _loadFx(input, generation),
    );
  }

  Future<void> _loadFx(FxPricingInput input, int generation) async {
    try {
      final service = await ref.read(fxQuoteServiceProvider.future);
      final quote = await service.resolve(input.currency!);
      if (!_acceptsFxResult(generation, input)) {
        return;
      }
      setState(() {
        _fxQuote = quote;
        _priceIdrPerPackage = FxConversion.packagePriceIdr(
          priceOriginal: input.priceOriginal!,
          fxRate: quote.rate,
        );
        _priceIdrPerKg = FxConversion.priceIdrPerKg(
          priceOriginal: input.priceOriginal!,
          fxRate: quote.rate,
          packSizeG: input.packSizeG!,
        );
        _isFxLoading = false;
        _fxMessage = null;
      });
    } on FxQuoteException catch (error) {
      _showFxError(generation, input, error.message);
    } catch (_) {
      _showFxError(
        generation,
        input,
        'Kurs belum tersedia. Biji tetap dapat disimpan tanpa harga rupiah.',
      );
    }
  }

  void _showFxError(int generation, FxPricingInput input, String message) {
    if (!_acceptsFxResult(generation, input)) {
      return;
    }
    setState(() {
      _clearFx();
      _fxMessage = message;
    });
  }

  bool _acceptsFxResult(int generation, FxPricingInput input) {
    return mounted &&
        _fxRequestGuard.accepts(generation, input) &&
        input == _currentPricingInput;
  }

  FxPricingInput get _currentPricingInput {
    return FxPricingInput(
      priceOriginal: _tryParseNumber(_priceController.text),
      currency: _currency,
      packSizeG: _tryParseNumber(_selectedPackSizeText),
    );
  }

  double? _tryParseNumber(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  void _restoreOriginalFx() {
    final bean = widget.initialBean;
    final rate = bean?.fxRate;
    final date = bean?.fxDate;
    final price = bean?.priceOriginal;
    final packSize = bean?.packSizeG;
    final pricePerKg = bean?.priceIdrPerKg;
    _isFxLoading = false;
    _fxMessage = null;
    if (rate == null ||
        date == null ||
        price == null ||
        packSize == null ||
        pricePerKg == null ||
        bean?.currency == null) {
      _fxQuote = null;
      _priceIdrPerPackage = null;
      _priceIdrPerKg = null;
      return;
    }
    _fxQuote = FxQuote(
      currency: bean!.currency!,
      rate: rate,
      date: date,
      source: bean.currency == 'IDR'
          ? FxQuoteSource.local
          : FxQuoteSource.network,
    );
    _priceIdrPerPackage = FxConversion.packagePriceIdr(
      priceOriginal: price,
      fxRate: rate,
    );
    _priceIdrPerKg = pricePerKg;
  }

  void _clearFx() {
    _isFxLoading = false;
    _fxQuote = null;
    _priceIdrPerPackage = null;
    _priceIdrPerKg = null;
    _fxMessage = null;
  }

  Widget _optionalChips<T>({
    required List<T> values,
    required T? selected,
    required String Function(T value) label,
    required bool enabled,
    required ValueChanged<T?> onChanged,
  }) {
    return _chipWrap(
      values
          .map(
            (value) => AppChip(
              label: label(value),
              selected: selected == value,
              onSelected: enabled
                  ? (isSelected) => onChanged(isSelected ? value : null)
                  : null,
            ),
          )
          .toList(),
    );
  }

  Widget _chipWrap(List<Widget> children) {
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: children,
    );
  }

  void _selectSpecies(BeanSpecies species) {
    setState(() {
      if (_species != species) {
        _arabicaPercent = species == BeanSpecies.campuran ? 50 : null;
      }
      _species = species;
      _errors = Map.of(_errors)
        ..remove('species')
        ..remove('arabicaPercent');
    });
  }

  void _toggleSelfRoasted(bool value) {
    setState(() {
      _isSelfRoasted = value;
      _roasteryController.text = value ? BeanDefaults.selfRoasteryName : '';
    });
  }

  void _selectProcess(BeanProcess? process) {
    setState(() {
      _process = process;
      if (process != BeanProcess.lainnya) {
        _processCustomController.clear();
      }
      _errors = Map.of(_errors)..remove('processCustom');
    });
  }

  void _selectStandardPack(double size, bool selected) {
    setState(() {
      _customPackSelected = false;
      _customPackController.clear();
      _packSizeG = selected ? size : null;
      _errors = Map.of(_errors)..remove('packSize');
      if (selected) {
        _autofillStock(size);
      }
    });
    _scheduleFxUpdate(immediate: true);
  }

  void _selectCustomPack(bool selected) {
    setState(() {
      _customPackSelected = selected;
      _packSizeG = null;
      if (!selected) {
        _customPackController.clear();
      }
      _errors = Map.of(_errors)..remove('packSize');
    });
    _scheduleFxUpdate(immediate: true);
  }

  void _onCustomPackChanged(String value) {
    _clearError('packSize');
    final size = double.tryParse(value.trim().replaceAll(',', '.'));
    if (size != null && size > 0) {
      setState(() => _autofillStock(size));
    }
    _scheduleFxUpdate();
  }

  void _autofillStock(double size) {
    if (!_stockEditedManually) {
      _stockController.text = _formatEditableNumber(size);
      _errors = Map.of(_errors)..remove('stock');
    }
  }

  void _toggleBuiltInTag(RoasteryNoteTag tag, bool selected) {
    setState(() {
      _selectedTags = {..._selectedTags};
      if (selected) {
        _selectedTags.add(tag.databaseValue);
      } else {
        _selectedTags.remove(tag.databaseValue);
      }
      _errors = Map.of(_errors)..remove('tags');
    });
  }

  Future<void> _addCustomTag() async {
    if (_selectedTags.length >= BeanValidation.maximumTagCount) {
      setState(() {
        _errors = {
          ..._errors,
          'tags': 'Maksimal ${BeanValidation.maximumTagCount} tag per biji.',
        };
      });
      return;
    }
    final value = await showDialog<String>(
      context: context,
      builder: (_) => const AppInputDialog(
        title: 'Tambah tasting note',
        fieldLabel: 'Nama tag',
        primaryLabel: 'Tambahkan',
        maxLength: BeanValidation.maximumCustomTagLength,
      ),
    );
    if (value == null || !mounted) {
      return;
    }
    final error = BeanValidation.validateCustomTag(
      value,
      existingTags: _selectedTags,
    );
    if (error != null) {
      setState(() => _errors = {..._errors, 'tags': error});
      return;
    }
    setState(() {
      _selectedTags = {..._selectedTags, BeanValidation.normalizeTag(value)};
      _errors = Map.of(_errors)..remove('tags');
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags = {..._selectedTags}..remove(tag);
      _errors = Map.of(_errors)..remove('tags');
    });
  }

  Future<void> _pickRoastDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_roastDate ?? '') ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Pilih tanggal roasting',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (selected != null && mounted) {
      setState(() => _roastDate = _formatDate(selected));
    }
  }

  Future<void> _submit() async {
    final packSizeText = _selectedPackSizeText;
    final pricingInput = _currentPricingInput;
    final errors = BeanValidation.validate(
      name: _nameController.text,
      species: _species,
      stockText: _stockController.text,
      priceText: _priceController.text,
      packSizeText: packSizeText,
      customPackSelected: _customPackSelected,
      currency: _currency,
      arabicaPercent: _arabicaPercent,
      process: _process,
      processCustom: _processCustomController.text,
      tags: _selectedTags,
    );
    final legacyPricingUnchanged =
        widget.initialBean?.priceOriginal != null &&
        widget.initialBean?.packSizeG == null &&
        pricingInput == _originalPricingInput;
    if (legacyPricingUnchanged) {
      errors.remove('packSize');
    }
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }

    final priceText = _priceController.text.trim();
    final draft = BeanDraft(
      name: _nameController.text,
      species: _species!,
      beanType: _beanType,
      arabicaPercent: _arabicaPercent,
      roastery: _roasteryController.text,
      isSelfRoasted: _isSelfRoasted,
      origin: _originController.text,
      process: _process,
      processCustom: _processCustomController.text,
      roastLevel: _roastLevel,
      roastDate: _roastDate,
      packSizeG: packSizeText.isEmpty
          ? null
          : BeanValidation.parseNumber(packSizeText),
      priceOriginal: priceText.isEmpty
          ? null
          : BeanValidation.parseNumber(priceText),
      currency: priceText.isEmpty ? null : _currency,
      fxRate: priceText.isEmpty ? null : _fxQuote?.rate,
      fxDate: priceText.isEmpty ? null : _fxQuote?.date,
      priceIdrPerKg: priceText.isEmpty ? null : _priceIdrPerKg,
      initialStockG: BeanValidation.parseNumber(_stockController.text),
      roasteryNotesTags: [..._selectedTags],
      roasteryNotesText: _notesController.text,
    );
    final savedId = await ref
        .read(beanMutationProvider.notifier)
        .save(draft: draft, beanId: widget.initialBean?.id);
    if (savedId != null && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  String get _selectedPackSizeText {
    if (_customPackSelected) {
      return _customPackController.text;
    }
    final size = _packSizeG;
    return size == null ? '' : _formatEditableNumber(size);
  }

  void _clearError(String field) {
    if (_errors.containsKey(field)) {
      setState(() => _errors = Map.of(_errors)..remove(field));
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatEditableNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.errorText});

  final String label;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        if (errorText != null) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(
            errorText!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}
