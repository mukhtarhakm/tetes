import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_chip.dart';
import '../../core/ui/focus_dark_theme.dart';
import '../../features/beans/bean_model.dart';
import '../../features/beans/fx_conversion.dart';
import '../../features/beans/state/bean_providers.dart';
import 'currency_calculator.dart';

/// Cek harga biji di toko luar negeri dalam rupiah, lalu bandingkan harga per
/// gram dengan biji yang sudah disimpan. Kurs diambil sekali per mata uang;
/// perhitungan berikutnya berjalan langsung saat angka diketik.
class CurrencyCalculatorScreen extends ConsumerStatefulWidget {
  const CurrencyCalculatorScreen({super.key});

  @override
  ConsumerState<CurrencyCalculatorScreen> createState() =>
      _CurrencyCalculatorScreenState();
}

class _CurrencyCalculatorScreenState
    extends ConsumerState<CurrencyCalculatorScreen> {
  static const _currencies = ['USD', 'EUR', 'JPY'];
  static const _packs = [100, 200, 250, 500, 1000];
  static const _doseG = 15.0;

  final _amount = TextEditingController();
  final _quotes = <String, FxQuote>{};
  String _currency = 'USD';
  int _packG = 250;
  bool _loadingRate = false;
  String? _rateError;
  int _requestVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadRate();
  }

  @override
  void dispose() {
    _requestVersion++;
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadRate() async {
    final currency = _currency;
    if (_quotes.containsKey(currency)) return;
    final version = ++_requestVersion;
    setState(() {
      _loadingRate = true;
      _rateError = null;
    });
    try {
      final service = await ref.read(fxQuoteServiceProvider.future);
      final quote = await service.resolve(currency);
      if (!mounted || version != _requestVersion) return;
      setState(() => _quotes[currency] = quote);
    } catch (_) {
      if (mounted && version == _requestVersion) {
        setState(
          () => _rateError =
              'Kurs $currency belum tersedia. Periksa internet lalu coba lagi.',
        );
      }
    } finally {
      if (mounted && version == _requestVersion) {
        setState(() => _loadingRate = false);
      }
    }
  }

  void _selectCurrency(String currency) {
    if (currency == _currency) return;
    setState(() => _currency = currency);
    _loadRate();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final quote = _quotes[_currency];
    final amount = CurrencyCalculator.parseAmount(_amount.text);
    final idr = quote == null || amount == null
        ? null
        : CurrencyCalculator.convertViaIdr(
            amount: amount,
            fromIdrRate: quote.rate,
            toIdrRate: 1,
          );
    final perGram = idr == null ? null : idr / _packG;
    final beans = ref.watch(beanListProvider).asData?.value ?? const <Bean>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Cek Harga Biji')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          AppSpacing.s4,
          AppSpacing.s20,
          AppSpacing.s24,
        ),
        children: [
          _PriceCard(
            amount: _amount,
            currencies: _currencies,
            currency: _currency,
            packs: _packs,
            packG: _packG,
            idr: idr,
            perGram: perGram,
            doseG: _doseG,
            loadingRate: _loadingRate,
            hasAmount: amount != null,
            onAmountChanged: () => setState(() {}),
            onCurrency: _selectCurrency,
            onPack: (pack) => setState(() => _packG = pack),
          ),
          const SizedBox(height: AppSpacing.s12),
          _CompareCard(perGram: perGram, beans: beans),
          const SizedBox(height: AppSpacing.s12),
          if (_rateError != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_rateError!),
                  TextButton(
                    onPressed: _loadingRate ? null : _loadRate,
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            )
          else if (quote != null)
            Row(
              children: [
                const Icon(
                  Icons.sync_rounded,
                  size: 16,
                  color: AppColors.inkSoft,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    '1 $_currency = ${formatRupiah(quote.rate, decimals: quote.rate < 1000 ? 2 : 0)}'
                    ' · kurs ${quote.date}'
                    '${quote.source == FxQuoteSource.cache ? ' · dari cache' : ''}',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PriceCard extends StatelessWidget {
  const _PriceCard({
    required this.amount,
    required this.currencies,
    required this.currency,
    required this.packs,
    required this.packG,
    required this.idr,
    required this.perGram,
    required this.doseG,
    required this.loadingRate,
    required this.hasAmount,
    required this.onAmountChanged,
    required this.onCurrency,
    required this.onPack,
  });

  final TextEditingController amount;
  final List<String> currencies;
  final String currency;
  final List<int> packs;
  final int packG;
  final double? idr;
  final double? perGram;
  final double doseG;
  final bool loadingRate;
  final bool hasAmount;
  final VoidCallback onAmountChanged;
  final ValueChanged<String> onCurrency;
  final ValueChanged<int> onPack;

  @override
  Widget build(BuildContext context) {
    return FocusDarkTheme(
      child: Builder(
        builder: (context) {
          final textTheme = Theme.of(context).textTheme;
          final soft = textTheme.bodySmall?.copyWith(color: AppColors.divider);
          return Container(
            padding: AppInsets.card,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Harga di toko luar negeri', style: soft),
                TextField(
                  controller: amount,
                  onChanged: (_) => onAmountChanged(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  cursorColor: AppColors.primary,
                  style: textTheme.displaySmall?.copyWith(
                    color: AppColors.onDark,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: textTheme.displaySmall?.copyWith(
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w800,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s8,
                    ),
                  ),
                ),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    for (final code in currencies)
                      AppChip(
                        label: code,
                        selected: code == currency,
                        onSelected: (_) => onCurrency(code),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                Text('Isi kemasan', style: soft),
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s8,
                  children: [
                    for (final pack in packs)
                      AppChip(
                        label: pack >= 1000 ? '${pack ~/ 1000} kg' : '$pack g',
                        selected: pack == packG,
                        onSelected: (_) => onPack(pack),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                const Divider(color: AppColors.chipDark, height: 1),
                const SizedBox(height: AppSpacing.s16),
                Text('Dalam rupiah', style: soft),
                const SizedBox(height: AppSpacing.s4),
                if (loadingRate && idr == null && hasAmount)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.s8),
                    child: SizedBox.square(
                      dimension: AppSizes.buttonProgress,
                      child: CircularProgressIndicator(
                        strokeWidth: AppSizes.progressStroke,
                        color: AppColors.accent,
                      ),
                    ),
                  )
                else
                  Text(
                    idr == null ? 'Rp -' : formatRupiah(idr!),
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: AppSpacing.s16,
                  runSpacing: AppSpacing.s4,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: perGram == null ? 'Rp -' : formatRupiah(perGram!),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.onDark,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [TextSpan(text: ' /g', style: soft)],
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        text: perGram == null
                            ? 'Rp -'
                            : formatRupiah(perGram! * doseG),
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.onDark,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(
                            text: ' /seduhan ${doseG.toStringAsFixed(0)} g',
                            style: soft,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.perGram, required this.beans});

  final double? perGram;
  final List<Bean> beans;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final priced = beans
        .where((bean) => (bean.priceIdrPerKg ?? 0) > 0)
        .map((bean) => (name: bean.name, perGram: bean.priceIdrPerKg! / 1000))
        .toList();

    if (priced.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dibanding biji kamu', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'Isi harga di profil biji kopi untuk membandingkan harga per gram.',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      );
    }

    final average =
        priced.fold<double>(0, (sum, item) => sum + item.perGram) /
        priced.length;
    final rows = [
      if (perGram != null) (name: 'Biji ini', perGram: perGram!, mine: true),
      for (final item in priced)
        (name: item.name, perGram: item.perGram, mine: false),
    ];
    final maxValue = rows.fold<double>(
      0,
      (max, row) => row.perGram > max ? row.perGram : max,
    );

    String? verdict;
    if (perGram != null && average > 0) {
      final diff = (perGram! - average) / average * 100;
      verdict = diff.abs() < 1
          ? 'Setara dengan rata-rata biji kamu'
          : '${diff.abs().round()}% ${diff < 0 ? 'lebih murah' : 'lebih mahal'} dari rata-rata biji kamu';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'Dibanding biji kamu',
                  style: textTheme.titleMedium,
                ),
              ),
              Text(
                'per gram',
                style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s10,
            ),
            decoration: BoxDecoration(
              color: verdict == null
                  ? AppColors.background
                  : AppColors.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
            child: Text(
              verdict == null
                  ? 'Rata-rata biji kamu ${formatRupiah(average)}/g. Ketik harga di atas untuk membandingkan.'
                  : '$verdict (${formatRupiah(average)}/g).',
              style: textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          for (final row in rows) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: row.mine ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(formatRupiah(row.perGram), style: textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: maxValue <= 0 ? 0 : row.perGram / maxValue,
                minHeight: 8,
                backgroundColor: AppColors.background,
                color: row.mine
                    ? AppColors.primary
                    : AppColors.primaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
          ],
        ],
      ),
    );
  }
}

/// Format rupiah dengan titik ribuan, misalnya `Rp 305.250`.
String formatRupiah(double value, {int decimals = 0}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final digits = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  if (parts.length > 1) buffer.write(',${parts[1]}');
  return 'Rp $buffer';
}
