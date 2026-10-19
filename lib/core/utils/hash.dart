import 'dart:convert';

import 'package:crypto/crypto.dart';

String buildHashInput({
  required String beanId,
  required double doseG,
  required double ratio,
  required int waterTempC,
  required String grind,
  required int totalTimeS,
  required int tasteScore,
  required Iterable<String> tasteTags,
  required String brewedAtUtc,
  required String prevHash,
}) {
  final sortedTags = tasteTags.toList()..sort();
  return [
    beanId,
    doseG.toStringAsFixed(1),
    _formatRatio(ratio),
    waterTempC.toString(),
    grind,
    totalTimeS.toString(),
    tasteScore.toString(),
    sortedTags.join(','),
    brewedAtUtc,
    prevHash,
  ].join('|');
}

String sha256Hex(String input) {
  return sha256.convert(utf8.encode(input)).toString();
}

String _formatRatio(double ratio) {
  if (!ratio.isFinite) {
    throw ArgumentError.value(ratio, 'ratio', 'Rasio harus berupa angka.');
  }
  final tenths = ratio * 10;
  if ((tenths - tenths.round()).abs() > 0.0000001) {
    throw ArgumentError.value(
      ratio,
      'ratio',
      'Rasio hanya boleh memakai satu angka desimal.',
    );
  }
  final formatted = ratio == ratio.roundToDouble()
      ? ratio.toStringAsFixed(0)
      : ratio.toStringAsFixed(1);
  return '1:$formatted';
}
