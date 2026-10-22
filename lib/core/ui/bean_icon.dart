import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

class BeanIcon extends StatelessWidget {
  const BeanIcon({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: AppSizes.navigationIcon,
    child: CustomPaint(
      painter: _BeanPainter(IconTheme.of(context).color ?? AppColors.ink),
    ),
  );
}

class _BeanPainter extends CustomPainter {
  const _BeanPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSizes.progressStroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..rotate(math.pi / 6)
      ..translate(-size.width / 2, -size.height / 2);
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .22,
        size.height * .12,
        size.width * .56,
        size.height * .76,
      ),
      paint,
    );
    final seam = Path()
      ..moveTo(size.width * .57, size.height * .18)
      ..cubicTo(
        size.width * .25,
        size.height * .36,
        size.width * .75,
        size.height * .64,
        size.width * .43,
        size.height * .82,
      );
    canvas.drawPath(seam, paint);
  }

  @override
  bool shouldRepaint(_BeanPainter oldDelegate) => oldDelegate.color != color;
}
