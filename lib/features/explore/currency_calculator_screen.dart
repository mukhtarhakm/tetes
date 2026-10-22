import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_dropdown_field.dart';
import '../../core/ui/app_text_field.dart';
import '../../features/beans/fx_conversion.dart';
import '../../features/beans/state/bean_providers.dart';
import 'currency_calculator.dart';

class CurrencyCalculatorScreen extends ConsumerStatefulWidget {
  const CurrencyCalculatorScreen({super.key});

  @override
  ConsumerState<CurrencyCalculatorScreen> createState() =>
      _CurrencyCalculatorScreenState();
}

class _CurrencyCalculatorScreenState
    extends ConsumerState<CurrencyCalculatorScreen> {
  static const _currencies = ['IDR', 'USD', 'EUR', 'JPY'];

  final _amount = TextEditingController();
  String _from = 'USD';
  String _to = 'IDR';
  String? _error;
  String? _result;
  String? _date;
  bool _fromCache = false;
  bool _loading = false;
  int _requestVersion = 0;

  @override
  void dispose() {
    _requestVersion++;
    _amount.dispose();
    super.dispose();
  }

  void _clearResult() {
    _requestVersion++;
    setState(() {
      _error = null;
      _result = null;
      _date = null;
      _loading = false;
    });
  }

  Future<void> _calculate() async {
    final amount = CurrencyCalculator.parseAmount(_amount.text);
    if (amount == null) {
      setState(() {
        _error = 'Masukkan jumlah lebih dari nol. Gunakan koma atau titik untuk desimal.';
        _result = null;
      });
      return;
    }
    final version = ++_requestVersion;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final service = await ref.read(fxQuoteServiceProvider.future);
      // Berurutan agar dua pembaruan cache tidak menimpa satu sama lain.
      final fromQuote = await service.resolve(_from);
      final toQuote = await service.resolve(_to);
      final converted = CurrencyCalculator.convertViaIdr(
        amount: amount,
        fromIdrRate: fromQuote.rate,
        toIdrRate: toQuote.rate,
      );
      if (!mounted || version != _requestVersion) return;
      final dates = [
        if (_from != 'IDR') '$_from ${fromQuote.date}',
        if (_to != 'IDR' && _to != _from) '$_to ${toQuote.date}',
      ];
      setState(() {
        _result = '${converted.toStringAsFixed(2)} $_to';
        _date = dates.isEmpty ? 'Mata uang sama; kurs tidak diperlukan.' :
            'Tanggal kurs: ${dates.join(' · ')}';
        _fromCache = fromQuote.source == FxQuoteSource.cache ||
            toQuote.source == FxQuoteSource.cache;
      });
    } catch (_) {
      if (mounted && version == _requestVersion) {
        setState(() => _error =
            'Kurs tidak tersedia. Periksa internet atau coba lagi saat cache kurs tersedia.');
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Kalkulator Kurs')),
    body: ListView(
      padding: AppInsets.screen,
      children: [
        AppTextField(
          controller: _amount,
          label: 'Jumlah',
          hintText: 'Contoh: 1.250,50',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _clearResult(),
        ),
        const SizedBox(height: AppSpacing.s16),
        AppDropdownField<String>(
          label: 'Dari mata uang',
          items: _currencies,
          itemLabel: (item) => item,
          value: _from,
          onChanged: (value) {
            if (value != null) {
              _from = value;
              _clearResult();
            }
          },
        ),
        const SizedBox(height: AppSpacing.s12),
        AppButton(
          label: 'Tukar mata uang',
          variant: AppButtonVariant.secondary,
          onPressed: () {
            final previous = _from;
            _from = _to;
            _to = previous;
            _clearResult();
          },
        ),
        const SizedBox(height: AppSpacing.s12),
        AppDropdownField<String>(
          label: 'Ke mata uang',
          items: _currencies,
          itemLabel: (item) => item,
          value: _to,
          onChanged: (value) {
            if (value != null) {
              _to = value;
              _clearResult();
            }
          },
        ),
        const SizedBox(height: AppSpacing.s20),
        AppButton(label: 'Hitung', isLoading: _loading,
          onPressed: _loading ? null : _calculate),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.s16),
          AppCard(child: Text(_error!)),
        ],
        if (_result != null) ...[
          const SizedBox(height: AppSpacing.s16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hasil', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.s8),
                Text(_result!, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.s8),
                Text(_date!),
                if (_fromCache) const Text('Dari cache'),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
