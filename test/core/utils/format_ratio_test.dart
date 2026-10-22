import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/core/utils/format_ratio.dart';

void main() {
  test('rasio bulat tanpa .0 dan pecahan satu desimal', () {
    expect(formatRatio(15), '1:15');
    expect(formatRatio(15.5), '1:15.5');
  });
}
