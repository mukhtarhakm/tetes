import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';

/// Logo Tetes: kerucut V60 dengan satu tetes. Digambar dengan CustomPaint
/// pada kotak 64x64 supaya tajam di semua ukuran.
class TetesLogo extends StatelessWidget {
  const TetesLogo({this.size = 64, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'Logo Tetes',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(painter: _TetesLogoPainter(onDark: isDark)),
        ),
      ),
    );
  }
}

class _TetesLogoPainter extends CustomPainter {
  const _TetesLogoPainter({required this.onDark});

  final bool onDark;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64;
    canvas.save();
    canvas.scale(scale);

    final boxColor = onDark ? AppColors.onDark : AppColors.ink;
    final coneColor = onDark ? AppColors.ink : AppColors.onDark;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 64, 64),
        const Radius.circular(18),
      ),
      Paint()..color = boxColor,
    );

    final cone = Path()
      ..moveTo(17, 19)
      ..lineTo(47, 19)
      ..lineTo(38.5, 34)
      ..lineTo(25.5, 34)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..color = coneColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final drop = Path()
      ..moveTo(32, 37.5)
      ..cubicTo(32, 37.5, 27.2, 43.6, 27.2, 47)
      ..arcToPoint(
        const Offset(36.8, 47),
        radius: const Radius.circular(4.8),
        clockwise: false,
      )
      ..cubicTo(36.8, 43.6, 32, 37.5, 32, 37.5)
      ..close();
    canvas.drawPath(drop, Paint()..color = AppColors.primary);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_TetesLogoPainter oldDelegate) =>
      oldDelegate.onDark != onDark;
}

/// Logo, nama, dan tagline untuk bagian atas layar Masuk dan Daftar.
class TetesBrand extends StatelessWidget {
  const TetesBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        const TetesLogo(),
        const SizedBox(width: AppSpacing.s16),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Tetes',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  height: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                'Jurnal seduh V60',
                style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
