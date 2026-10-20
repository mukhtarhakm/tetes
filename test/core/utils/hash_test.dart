import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/core/utils/hash.dart';
import 'package:tetes/features/brew/brew_plan.dart';

void main() {
  const entry1Input =
      '11111111-1111-4111-8111-111111111111|15.0|1:16|92|sedang|195|3|asam,cokelat|2026-10-17T08:30:00Z|0';
  const entry1Hash =
      'bff83b62a198e4eeb8feb965b721030ae4e0c6c4122cf8c2e6acf8481bd00e34';
  const entry2Input =
      '11111111-1111-4111-8111-111111111111|15.0|1:15|90|sedang|185|4|cokelat,seimbang|2026-10-18T08:30:00Z|bff83b62a198e4eeb8feb965b721030ae4e0c6c4122cf8c2e6acf8481bd00e34';
  const entry2Hash =
      '2fbdd892eb66dc64c4436c654ad6ada4c6eaaf50252f9cf21c5adb05105fdd3c';

  test('vektor uji entri 1 menghasilkan teks dan hash persis', () {
    final input = buildHashInput(
      beanId: '11111111-1111-4111-8111-111111111111',
      doseG: 15,
      ratio: 16,
      waterTempC: 92,
      grind: Grind.sedang.databaseValue,
      totalTimeS: 195,
      tasteScore: 3,
      tasteTags: const ['asam', 'cokelat'],
      brewedAtUtc: '2026-10-17T08:30:00Z',
      prevHash: '0',
    );

    expect(input, entry1Input);
    expect(sha256Hex(input), entry1Hash);
  });

  test('vektor uji entri 2 memakai hash entri 1 sebagai prev_hash', () {
    final input = buildHashInput(
      beanId: '11111111-1111-4111-8111-111111111111',
      doseG: 15,
      ratio: 15,
      waterTempC: 90,
      grind: Grind.sedang.databaseValue,
      totalTimeS: 185,
      tasteScore: 4,
      tasteTags: const ['cokelat', 'seimbang'],
      brewedAtUtc: '2026-10-18T08:30:00Z',
      prevHash: entry1Hash,
    );

    expect(input, entry2Input);
    expect(sha256Hex(input), entry2Hash);
  });

  test('input sama menghasilkan hash yang sama', () {
    expect(sha256Hex(entry1Input), sha256Hex(entry1Input));
  });

  test('satu field berubah menghasilkan hash berbeda', () {
    final changed = entry1Input.replaceFirst('|195|', '|196|');

    expect(sha256Hex(changed), isNot(entry1Hash));
  });

  test('format dosis, ratio bulat, dan ratio desimal tepat', () {
    final integerRatio = _input(doseG: 15, ratio: 16);
    final decimalRatio = _input(doseG: 15, ratio: 15.5);

    expect(integerRatio.split('|')[1], '15.0');
    expect(integerRatio.split('|')[2], '1:16');
    expect(decimalRatio.split('|')[2], '1:15.5');
  });

  test('taste_tags yang tidak berurutan diurutkan sebelum digabung', () {
    final input = _input(
      doseG: 15,
      ratio: 16,
      tasteTags: const ['seimbang', 'asam', 'cokelat'],
    );

    expect(input.split('|')[7], 'asam,cokelat,seimbang');
  });

  test('daftar kosong adalah rantai utuh dengan nol entri', () {
    expect(verifyChain(const []), 'utuh (0 entri)');
  });

  test('rantai utuh tetap menghitung entri dibatalkan', () {
    final first = _chainEntry(
      seq: 1,
      data: _hashData(),
      prevHash: '0',
      hash: entry1Hash,
    );
    final second = _chainEntry(
      seq: 2,
      data: _secondHashData(),
      prevHash: entry1Hash,
      hash: entry2Hash,
      status: 'dibatalkan',
    );

    expect(hashEntry(first.data, first.prevHash), entry1Hash);
    expect(hashEntry(second.data, second.prevHash), entry2Hash);
    expect(verifyChain([first, second]), 'utuh (2 entri)');
  });

  test('nilai inti yang diubah memutus rantai di entri pertama yang gagal', () {
    final entries = [
      _chainEntry(seq: 1, data: _hashData(), prevHash: '0', hash: entry1Hash),
      _chainEntry(
        seq: 2,
        data: _secondHashData(totalTimeS: 186),
        prevHash: entry1Hash,
        hash: entry2Hash,
      ),
    ];

    expect(verifyChain(entries), 'rantai putus di seq 2');
  });

  test('celah seq melaporkan seq yang seharusnya ada', () {
    final entries = [
      _chainEntry(seq: 1, data: _hashData(), prevHash: '0', hash: entry1Hash),
      _chainEntry(
        seq: 3,
        data: _secondHashData(),
        prevHash: entry1Hash,
        hash: entry2Hash,
      ),
    ];

    expect(verifyChain(entries), 'rantai putus di seq 2');
  });

  test('prev_hash yang tidak cocok memutus rantai', () {
    const wrongPrevHash = 'f';
    final entries = [
      _chainEntry(seq: 1, data: _hashData(), prevHash: '0', hash: entry1Hash),
      _chainEntry(
        seq: 2,
        data: _secondHashData(),
        prevHash: wrongPrevHash,
        hash: hashEntry(_secondHashData(), wrongPrevHash),
      ),
    ];

    expect(verifyChain(entries), 'rantai putus di seq 2');
  });
}

BrewHashData _hashData() => (
  beanId: '11111111-1111-4111-8111-111111111111',
  doseG: 15,
  ratio: 16,
  waterTempC: 92,
  grind: Grind.sedang.databaseValue,
  totalTimeS: 195,
  tasteScore: 3,
  tasteTags: const ['asam', 'cokelat'],
  brewedAtUtc: '2026-10-17T08:30:00Z',
);

BrewHashData _secondHashData({int totalTimeS = 185}) => (
  beanId: '11111111-1111-4111-8111-111111111111',
  doseG: 15,
  ratio: 15,
  waterTempC: 90,
  grind: Grind.sedang.databaseValue,
  totalTimeS: totalTimeS,
  tasteScore: 4,
  tasteTags: const ['cokelat', 'seimbang'],
  brewedAtUtc: '2026-10-18T08:30:00Z',
);

BrewChainEntry _chainEntry({
  required int seq,
  required BrewHashData data,
  required String prevHash,
  required String hash,
  String status = 'aktif',
}) => (seq: seq, data: data, prevHash: prevHash, hash: hash, status: status);

String _input({
  required double doseG,
  required double ratio,
  Iterable<String> tasteTags = const [],
}) {
  return buildHashInput(
    beanId: '11111111-1111-4111-8111-111111111111',
    doseG: doseG,
    ratio: ratio,
    waterTempC: 92,
    grind: Grind.sedang.databaseValue,
    totalTimeS: 195,
    tasteScore: 3,
    tasteTags: tasteTags,
    brewedAtUtc: '2026-10-17T08:30:00Z',
    prevHash: '0',
  );
}
