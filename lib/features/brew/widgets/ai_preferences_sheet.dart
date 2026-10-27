import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_chip.dart';
import '../../../core/ui/app_text_field.dart';
import '../ai_brew.dart';

/// Lembar opsional sebelum rekomendasi AI.
///
/// Mengembalikan preferensi (bisa kosong bila pengguna menekan Lewati),
/// atau null bila lembar ditutup tanpa memilih apa pun.
Future<AiRecommendPreferences?> showAiPreferencesSheet(BuildContext context) {
  return showModalBottomSheet<AiRecommendPreferences>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (_) => const AiPreferencesSheet(),
  );
}

class AiPreferencesSheet extends StatefulWidget {
  const AiPreferencesSheet({super.key});

  @override
  State<AiPreferencesSheet> createState() => _AiPreferencesSheetState();
}

class _AiPreferencesSheetState extends State<AiPreferencesSheet> {
  final _dose = TextEditingController();
  final _wish = TextEditingController();
  int? _pouringCount;
  String? _doseError;

  @override
  void dispose() {
    _dose.dispose();
    _wish.dispose();
    super.dispose();
  }

  void _submit() {
    var wish = _wish.text.trim();
    // Server menghitung panjang per code point; potong agar tidak ditolak.
    final runes = wish.runes;
    if (runes.length > AiRecommendPreferences.maxWishLength) {
      wish = String.fromCharCodes(
        runes.take(AiRecommendPreferences.maxWishLength),
      ).trim();
    }
    Navigator.of(context).pop(
      AiRecommendPreferences(
        doseG: AiRecommendPreferences.parseDose(_dose.text),
        pouringCount: _pouringCount,
        wish: wish.isEmpty ? null : wish,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final quiet = textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          0,
          AppSpacing.s20,
          AppSpacing.s20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sebelum AI menyarankan', style: textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s4),
            Text(
              'Semua opsional. Biarkan kosong kalau mau AI yang menentukan.',
              style: quiet,
            ),
            const SizedBox(height: AppSpacing.s20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dosis kopi', style: textTheme.labelLarge),
                      const SizedBox(height: AppSpacing.s4),
                      Text('Kosongkan kalau mau AI yang pilih', style: quiet),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    key: const Key('ai-pref-dose'),
                    controller: _dose,
                    hintText: '15',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    suffixIcon: const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.s12),
                      child: Align(
                        alignment: Alignment.centerRight,
                        widthFactor: 1,
                        child: Text('g'),
                      ),
                    ),
                    onChanged: (value) => setState(
                      () => _doseError = AiRecommendPreferences.doseError(value),
                    ),
                  ),
                ),
              ],
            ),
            if (_doseError != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                _doseError!,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.s20),
            Text('Jumlah pouring', style: textTheme.labelLarge),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                AppChip(
                  label: 'Biar AI pilih',
                  selected: _pouringCount == null,
                  onSelected: (_) => setState(() => _pouringCount = null),
                ),
                for (var count = 1; count <= 5; count++)
                  AppChip(
                    label: '$count',
                    selected: _pouringCount == count,
                    onSelected: (_) => setState(() => _pouringCount = count),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s20),
            AppTextField(
              key: const Key('ai-pref-wish'),
              controller: _wish,
              label: 'Keinginanmu',
              hintText: 'mis. pengen lebih manis dan fruity, jangan terlalu asam',
              maxLines: 3,
              maxLength: AiRecommendPreferences.maxWishLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Lewati',
                    variant: AppButtonVariant.secondary,
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(const AiRecommendPreferences()),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: AppButton(
                    label: 'Minta saran',
                    icon: Icons.auto_awesome_outlined,
                    onPressed: _doseError == null ? _submit : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
