String formatRatio(double ratio) =>
    ratio % 1 == 0 ? '1:${ratio.toInt()}' : '1:${ratio.toStringAsFixed(1)}';
