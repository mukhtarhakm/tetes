/// Rupiah dengan titik ribuan, mis. `Rp15.000` atau `Rp 15.000` bila [spaced].
String formatIdr(double value, {bool spaced = false}) {
  final digits = value.round().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  return spaced ? 'Rp $grouped' : 'Rp$grouped';
}
