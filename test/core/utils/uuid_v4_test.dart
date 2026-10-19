import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/core/utils/uuid_v4.dart';

void main() {
  test('membuat UUID v4 huruf kecil', () {
    final first = createUuidV4();
    final second = createUuidV4();

    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(second, isNot(first));
  });
}
