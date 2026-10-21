import 'event_time.dart';

abstract final class EventDisplay {
  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
  static const _months = [
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

  static String clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  static String date(DateTime value) =>
      '${_days[value.weekday - 1]}, ${value.day} ${_months[value.month - 1]} ${value.year}';

  static String eventTime(DateTime utc, String sourceZone) {
    final local = EventTime.fromUtc(utc, sourceZone);
    final label = EventTime.zones.entries
        .firstWhere((entry) => entry.value == sourceZone)
        .key;
    return '${date(local)} · ${clock(local)} $label';
  }

  static int calendarDayDifference(DateTime source, DateTime target) {
    final sourceDay = DateTime.utc(source.year, source.month, source.day);
    final targetDay = DateTime.utc(target.year, target.month, target.day);
    return targetDay.difference(sourceDay).inDays;
  }

  static String dayOffset(DateTime source, DateTime target) {
    final days = calendarDayDifference(source, target);
    if (days == 0) return '';
    return '${days > 0 ? '+' : ''}$days hari';
  }

  static String countdown(DateTime startUtc, DateTime now) {
    final remaining = startUtc.toUtc().difference(now.toUtc());
    if (remaining <= Duration.zero) return 'Selesai';
    if (remaining < const Duration(hours: 1)) {
      final minutes = (remaining.inSeconds / 60).ceil().clamp(1, 59);
      return '$minutes menit lagi';
    }
    final days = calendarDayDifference(now.toLocal(), startUtc.toLocal());
    if (days == 0) {
      if (remaining < const Duration(hours: 6)) {
        return '${remaining.inHours} jam lagi';
      }
      return 'Hari ini';
    }
    if (days == 1) return 'Besok';
    return '$days hari lagi';
  }
}
