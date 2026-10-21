import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/core/utils/event_time.dart';

void main() {
  test('London BST dan GMT berubah sesuai tanggal', () {
    final summer = EventTime.toUtc(
      DateTime(2026, 7, 1),
      14,
      0,
      'Europe/London',
    );
    expect(EventTime.utcText(summer), '2026-07-01T13:00:00Z');
    expect(EventTime.localText(summer, 'Asia/Jakarta'), '01/07/2026 20:00');
    final winter = EventTime.toUtc(
      DateTime(2026, 12, 1),
      14,
      0,
      'Europe/London',
    );
    expect(EventTime.utcText(winter), '2026-12-01T14:00:00Z');
    expect(EventTime.localText(winter, 'Asia/Jakarta'), '01/12/2026 21:00');
  });

  test('WIB, WITA, WIT memakai UTC+7, +8, +9', () {
    final date = DateTime(2026, 7, 1);
    expect(
      EventTime.utcText(EventTime.toUtc(date, 14, 0, 'Asia/Jakarta')),
      '2026-07-01T07:00:00Z',
    );
    expect(
      EventTime.utcText(EventTime.toUtc(date, 14, 0, 'Asia/Makassar')),
      '2026-07-01T06:00:00Z',
    );
    expect(
      EventTime.utcText(EventTime.toUtc(date, 14, 0, 'Asia/Jayapura')),
      '2026-07-01T05:00:00Z',
    );
  });

  test('jam London ambigu dan tidak ada memberi tindakan', () {
    expect(
      () => EventTime.toUtc(DateTime(2026, 10, 25), 1, 30, 'Europe/London'),
      throwsA(
        predicate(
          (e) =>
              e is ArgumentError &&
              e.message.toString().contains('Pilih jam lain'),
        ),
      ),
    );
    expect(
      () => EventTime.toUtc(DateTime(2027, 3, 28), 1, 30, 'Europe/London'),
      throwsA(
        predicate(
          (e) =>
              e is ArgumentError &&
              e.message.toString().contains('Pilih jam lain'),
        ),
      ),
    );
  });
}
