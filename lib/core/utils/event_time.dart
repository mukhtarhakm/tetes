import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

abstract final class EventTime {
  static const zones = {
    'WIB': 'Asia/Jakarta',
    'WITA': 'Asia/Makassar',
    'WIT': 'Asia/Jayapura',
    'London': 'Europe/London',
  };

  static bool _initialized = false;

  static tz.Location _location(String zone) {
    if (!zones.containsValue(zone)) {
      throw ArgumentError.value(zone, 'zone', 'Zona waktu tidak didukung.');
    }
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
    return tz.getLocation(zone);
  }

  static DateTime toUtc(DateTime date, int hour, int minute, String zone) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw ArgumentError('Jam event tidak valid. Pilih jam lain.');
    }
    final location = _location(zone);
    final local = tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
    final utc = local.toUtc();
    if (local.year != date.year ||
        local.month != date.month ||
        local.day != date.day ||
        local.hour != hour ||
        local.minute != minute) {
      throw ArgumentError('Jam ini tidak ada di zona event. Pilih jam lain.');
    }
    // Saat jam London mundur, kedua UTC berbeda menunjukkan jam lokal sama.
    for (final offset in [
      -const Duration(hours: 1),
      const Duration(hours: 1),
    ]) {
      final alternate = tz.TZDateTime.from(utc.add(offset), location);
      if (alternate.year == date.year &&
          alternate.month == date.month &&
          alternate.day == date.day &&
          alternate.hour == hour &&
          alternate.minute == minute) {
        throw ArgumentError(
          'Jam ini muncul dua kali di zona event. Pilih jam lain.',
        );
      }
    }
    return utc;
  }

  static tz.TZDateTime fromUtc(DateTime utc, String zone) =>
      tz.TZDateTime.from(utc.toUtc(), _location(zone));

  static String utcText(DateTime utc) =>
      utc.toUtc().toIso8601String().replaceFirst(RegExp(r'\.\d+Z$'), 'Z');

  static String localText(DateTime utc, String zone) {
    final value = fromUtc(utc, zone);
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
