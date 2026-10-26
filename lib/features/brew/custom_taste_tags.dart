import '../beans/bean_model.dart';

List<String> normalizeCustomTasteTags(Iterable<String> values) {
  final result = <String>[];
  final seen = <String>{};
  for (final value in values) {
    final tag = value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    if (tag.isEmpty) {
      throw const FormatException('Rasa lain tidak boleh kosong.');
    }
    if (tag.runes.length > 20) {
      throw const FormatException('Rasa lain maksimal 20 karakter.');
    }
    if (!RegExp(r'^[\p{L}\p{N} -]+$', unicode: true).hasMatch(tag)) {
      throw const FormatException(
        'Rasa lain hanya boleh berisi huruf, angka, spasi, dan tanda hubung.',
      );
    }
    if (RoasteryNoteTag.isBuiltIn(tag)) {
      throw const FormatException('Rasa ini sudah ada di pilihan bawaan.');
    }
    if (seen.add(tag)) result.add(tag);
  }
  if (result.length > 3) {
    throw const FormatException('Maksimal 3 rasa lain per seduhan.');
  }
  return result;
}
