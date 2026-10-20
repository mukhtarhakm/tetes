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

typedef BrewHashData = ({
  String beanId,
  double doseG,
  double ratio,
  int waterTempC,
  String grind,
  int totalTimeS,
  int tasteScore,
  Iterable<String> tasteTags,
  String brewedAtUtc,
});

typedef BrewChainEntry = ({
  int seq,
  BrewHashData data,
  String prevHash,
  String hash,
  String status,
});

String hashEntry(BrewHashData data, String prevHash) {
  return sha256Hex(
    buildHashInput(
      beanId: data.beanId,
      doseG: data.doseG,
      ratio: data.ratio,
      waterTempC: data.waterTempC,
      grind: data.grind,
      totalTimeS: data.totalTimeS,
      tasteScore: data.tasteScore,
      tasteTags: data.tasteTags,
      brewedAtUtc: data.brewedAtUtc,
      prevHash: prevHash,
    ),
  );
}

String verifyChain(Iterable<BrewChainEntry> entries) {
  var expectedSeq = 1;
  var previousHash = '0';
  for (final entry in entries) {
    if (entry.seq != expectedSeq || entry.prevHash != previousHash) {
      return 'rantai putus di seq $expectedSeq';
    }
    try {
      if (entry.hash != hashEntry(entry.data, entry.prevHash)) {
        return 'rantai putus di seq $expectedSeq';
      }
    } on ArgumentError {
      return 'rantai putus di seq $expectedSeq';
    }
    previousHash = entry.hash;
    expectedSeq++;
  }
  return 'utuh (${expectedSeq - 1} entri)';
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
