import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/core/utils/event_display.dart';
import 'package:tetes/core/utils/event_time.dart';

void main() {
  test('tanggal Indonesia mencakup semua nama hari dan bulan', () {
    final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    for (var i = 0; i < days.length; i++) {
      expect(
        EventDisplay.date(DateTime.utc(2026, 10, 19 + i)),
        startsWith('${days[i]},'),
      );
    }
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    for (var i = 0; i < months.length; i++) {
      expect(
        EventDisplay.date(DateTime.utc(2026, i + 1, 1)),
        contains(' ${months[i]} 2026'),
      );
    }
    expect(EventDisplay.date(DateTime.utc(2026, 10, 22)), 'Kam, 22 Okt 2026');
  });

  test('selisih hari London ke WIB memakai tanggal lokal tiap zona', () {
    final late = EventTime.toUtc(DateTime(2026, 7, 1), 23, 0, 'Europe/London');
    final londonLate = EventTime.fromUtc(late, 'Europe/London');
    final wibLate = EventTime.fromUtc(late, 'Asia/Jakarta');
    expect(EventDisplay.dayOffset(londonLate, wibLate), '+1 hari');
    expect(
      EventDisplay.eventTime(late, 'Europe/London'),
      'Rab, 1 Jul 2026 · 23:00 London',
    );

    final early = EventTime.toUtc(DateTime(2026, 7, 1), 14, 0, 'Europe/London');
    expect(
      EventDisplay.dayOffset(
        EventTime.fromUtc(early, 'Europe/London'),
        EventTime.fromUtc(early, 'Asia/Jakarta'),
      ),
      isEmpty,
    );
  });

  test('hitung mundur mengikuti batas waktu dan tanggal perangkat', () {
    final now = DateTime(2026, 10, 21, 12);
    String label(DateTime start, [DateTime? current]) =>
        EventDisplay.countdown(start.toUtc(), current ?? now);
    expect(label(now), 'Selesai');
    expect(label(now.subtract(const Duration(minutes: 1))), 'Selesai');
    expect(label(now.add(const Duration(minutes: 59))), '59 menit lagi');
    expect(label(now.add(const Duration(minutes: 61))), '1 jam lagi');
    expect(label(now.add(const Duration(hours: 5))), '5 jam lagi');
    expect(label(now.add(const Duration(hours: 7))), 'Hari ini');
    final nearMidnight = DateTime(2026, 10, 21, 23, 50);
    expect(label(DateTime(2026, 10, 22, 0, 30), nearMidnight), '40 menit lagi');
    final atEleven = DateTime(2026, 10, 21, 23);
    expect(label(DateTime(2026, 10, 22, 10), atEleven), 'Besok');
    expect(label(DateTime(2026, 10, 23, 12)), '2 hari lagi');
    expect(label(DateTime(2026, 10, 31, 12)), '10 hari lagi');
  });
}
