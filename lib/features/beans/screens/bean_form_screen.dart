import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_text_field.dart';
import '../bean_model.dart';
import '../bean_validation.dart';
import '../state/bean_providers.dart';

class BeanFormScreen extends ConsumerStatefulWidget {
  const BeanFormScreen({this.initialBean, super.key});

  final Bean? initialBean;

  @override
  ConsumerState<BeanFormScreen> createState() => _BeanFormScreenState();
}

class _BeanFormScreenState extends ConsumerState<BeanFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _roasteryController;
  late final TextEditingController _originController;
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
  String? _currency;
  Set<RoasteryNoteTag> _selectedTags = {};
  Map<String, String> _errors = const {};

  static const _currencies = ['IDR', 'USD', 'EUR', 'JPY'];

  @override
  void initState() {
    super.initState();
    final bean = widget.initialBean;
    _nameController = TextEditingController(text: bean?.name);
    _roasteryController = TextEditingController(text: bean?.roastery);
    _originController = TextEditingController(text: bean?.origin);
    _priceController = TextEditingController(
      text: bean?.priceOriginal == null
          ? null
          : _formatEditableNumber(bean!.priceOriginal!),
    );
    _stockController = TextEditingController(
      text: _formatEditableNumber(bean?.initialStockG ?? 0),
    );
    _notesController = TextEditingController(text: bean?.roasteryNotesText);
    _species = bean?.species;
    _beanType = bean?.beanType;
    _process = bean?.process;
    _roastLevel = bean?.roastLevel;
    _arabicaPercent = bean?.arabicaPercent;
    _isSelfRoasted = bean?.isSelfRoasted ?? false;
    _roastDate = bean?.roastDate;
    _currency = bean?.currency;
    _selectedTags = {...?bean?.roasteryNotesTags};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roasteryController.dispose();
    _originController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mutation = ref.watch(beanMutationProvider);
    final isSaving = mutation.isLoading;
    final sortedTags = [...RoasteryNoteTag.values]
      ..sort((left, right) => left.label.compareTo(right.label));

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
              AppTextField(
                controller: _nameController,
                label: 'Nama *',
                errorText: _errors['name'],
                enabled: !isSaving,
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearError('name'),
              ),
              const SizedBox(height: AppSpacing.s20),
              _SectionLabel(label: 'Spesies *', errorText: _errors['species']),
              const SizedBox(height: AppSpacing.s8),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: BeanSpecies.values
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
              if (_species == BeanSpecies.campuran) ...[
                const SizedBox(height: AppSpacing.s16),
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
              const SizedBox(height: AppSpacing.s20),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Roasting sendiri',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                value: _isSelfRoasted,
                onChanged: isSaving ? null : _toggleSelfRoasted,
              ),
              const SizedBox(height: AppSpacing.s8),
              AppTextField(
                controller: _roasteryController,
                label: 'Roastery',
                enabled: !isSaving && !_isSelfRoasted,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.s20),
              AppTextField(
                controller: _originController,
                label: 'Asal',
                enabled: !isSaving,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.s20),
              const _SectionLabel(label: 'Proses'),
              const SizedBox(height: AppSpacing.s8),
              _optionalChips<BeanProcess>(
                values: BeanProcess.values,
                selected: _process,
                label: (value) => value.label,
                enabled: !isSaving,
                onChanged: (value) => setState(() => _process = value),
              ),
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
              const SizedBox(height: AppSpacing.s20),
              AppTextField(
                controller: _priceController,
                label: 'Harga per kg',
                hintText: 'Opsional',
                errorText: _errors['price'],
                enabled: !isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearError('price'),
              ),
              const SizedBox(height: AppSpacing.s16),
              _SectionLabel(label: 'Mata uang', errorText: _errors['currency']),
              const SizedBox(height: AppSpacing.s8),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: _currencies
                    .map(
                      (currency) => AppChip(
                        label: currency,
                        selected: _currency == currency,
                        onSelected: isSaving
                            ? null
                            : (selected) {
                                setState(() {
                                  _currency = selected ? currency : null;
                                  _errors = Map.of(_errors)..remove('currency');
                                });
                              },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppSpacing.s20),
              AppTextField(
                controller: _stockController,
                label: 'Stok awal (g)',
                errorText: _errors['stock'],
                enabled: !isSaving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                onChanged: (_) => _clearError('stock'),
              ),
              const SizedBox(height: AppSpacing.s20),
              const _SectionLabel(label: 'Tasting notes roastery'),
              const SizedBox(height: AppSpacing.s8),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: sortedTags
                    .map(
                      (tag) => AppChip(
                        label: tag.label,
                        selected: _selectedTags.contains(tag),
                        onSelected: isSaving
                            ? null
                            : (selected) => _toggleTag(tag, selected),
                      ),
                    )
                    .toList(),
              ),
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
                onPressed: isSaving ? null : _submit,
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

  Widget _optionalChips<T>({
    required List<T> values,
    required T? selected,
    required String Function(T value) label,
    required bool enabled,
    required ValueChanged<T?> onChanged,
  }) {
    return Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: values
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

  void _toggleTag(RoasteryNoteTag tag, bool selected) {
    setState(() {
      _selectedTags = {..._selectedTags};
      if (selected) {
        _selectedTags.add(tag);
      } else {
        _selectedTags.remove(tag);
      }
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
      setState(() {
        _roastDate = _formatDate(selected);
      });
    }
  }

  Future<void> _submit() async {
    final errors = BeanValidation.validate(
      name: _nameController.text,
      species: _species,
      stockText: _stockController.text,
      priceText: _priceController.text,
      currency: _currency,
      arabicaPercent: _arabicaPercent,
    );
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
      });
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
      roastLevel: _roastLevel,
      roastDate: _roastDate,
      priceOriginal: priceText.isEmpty
          ? null
          : BeanValidation.parseNumber(priceText),
      currency: priceText.isEmpty ? null : _currency,
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

  void _clearError(String field) {
    if (_errors.containsKey(field)) {
      setState(() {
        _errors = Map.of(_errors)..remove(field);
      });
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
