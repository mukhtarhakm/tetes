abstract final class CurrencyCalculator {
  static double? parseAmount(String input) {
    final value = input.trim().replaceAll(RegExp(r'\s'), '');
    if (value.isEmpty || !RegExp(r'^[0-9.,]+$').hasMatch(value)) return null;
    final comma = value.lastIndexOf(',');
    final dot = value.lastIndexOf('.');
    final separator = comma > dot ? ',' : '.';
    final position = comma > dot ? comma : dot;
    String normalized;
    if (position < 0) {
      normalized = value;
    } else {
      final parts = value.split(separator);
      final grouped = parts.length > 2 &&
          parts.skip(1).every((part) => part.length == 3);
      if (parts.length > 2 && !grouped &&
          !value.contains(separator == ',' ? '.' : ',')) {
        return null;
      }
      final singleThousands = parts.length == 2 &&
          parts.last.length == 3 &&
          parts.first != '0' &&
          !value.contains(separator == ',' ? '.' : ',');
      if (grouped || singleThousands) {
        normalized = value.replaceAll(separator, '');
      } else {
        final whole = value.substring(0, position).replaceAll(RegExp(r'[.,]'), '');
        final fraction = value.substring(position + 1);
        if (fraction.isEmpty || fraction.contains(RegExp(r'[.,]'))) return null;
        normalized = '$whole.$fraction';
      }
    }
    final result = double.tryParse(normalized);
    return result != null && result.isFinite && result > 0 ? result : null;
  }

  static double convertViaIdr({
    required double amount,
    required double fromIdrRate,
    required double toIdrRate,
  }) {
    if (!amount.isFinite || amount <= 0 ||
        !fromIdrRate.isFinite || fromIdrRate <= 0 ||
        !toIdrRate.isFinite || toIdrRate <= 0) {
      throw ArgumentError('Nilai kurs atau jumlah tidak valid.');
    }
    return amount * fromIdrRate / toIdrRate;
  }
}
