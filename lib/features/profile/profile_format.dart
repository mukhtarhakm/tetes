const _months = [
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

String _two(int value) => value.toString().padLeft(2, '0');

/// "18 Okt 2026"
String formatJoinedDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

/// Jam 24 jam dengan titik: "08.00".
String formatClock(int hour, int minute) => '${_two(hour)}.${_two(minute)}';

/// "hari ini, 20.31", "kemarin, 20.31", atau "18 Okt, 20.31".
String formatRelativeDateTime(DateTime value, DateTime now) {
  final day = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  final difference = today.difference(day).inDays;
  final clock = formatClock(value.hour, value.minute);
  if (difference == 0) return 'hari ini, $clock';
  if (difference == 1) return 'kemarin, $clock';
  return '${value.day} ${_months[value.month - 1]}, $clock';
}

/// Rata-rata skor satu desimal dengan koma, atau "-" bila belum ada.
String formatAverageScore(double? average) =>
    average == null ? '-' : average.toStringAsFixed(1).replaceAll('.', ',');

const _dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

/// Ringkasan hari pengingat: "Setiap hari", "Senin sampai Jumat", dst.
String describeReminderDays(Set<int> days) {
  if (days.length == 7) return 'Setiap hari';
  if (days.length == 5 && days.containsAll(const {1, 2, 3, 4, 5})) {
    return 'Senin sampai Jumat';
  }
  if (days.length == 2 && days.containsAll(const {6, 7})) {
    return 'Akhir pekan';
  }
  final sorted = days.where((day) => day >= 1 && day <= 7).toList()..sort();
  if (sorted.isEmpty) return 'Belum ada hari dipilih';
  return sorted.map((day) => _dayNames[day - 1]).join(', ');
}
