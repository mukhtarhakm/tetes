// Format tampilan bersama agar layar tidak menyalin fungsi yang sama.

/// Angka bulat tanpa desimal, selain itu satu desimal (mis. 15 atau 15.5).
String formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

/// Detik menjadi `mm:ss` (mis. 125 -> 02:05).
String formatClock(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Waktu UTC ISO menjadi waktu lokal, mis. `5 Mei 2026, 08:30`.
/// Teks yang tidak bisa dibaca dikembalikan apa adanya.
String formatBrewedAt(String utcString) {
  final dt = DateTime.tryParse(utcString)?.toLocal();
  if (dt == null) return utcString;
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${_months[dt.month - 1]} ${dt.year}, $hour:$minute';
}
