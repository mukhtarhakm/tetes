import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../steady_pour_game.dart';

class GameBoard extends StatelessWidget {
  const GameBoard({required this.game, super.key});

  final GameState game;

  @override
  Widget build(BuildContext context) => Semantics(
    label: game.isInsideZone ? 'Titik di dalam zona' : 'Titik di luar zona',
    child: AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(painter: _GameBoardPainter(game)),
    ),
  );
}

class _GameBoardPainter extends CustomPainter {
  const _GameBoardPainter(this.game);

  final GameState game;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - AppSpacing.s24;
    canvas.drawCircle(center, radius, Paint()..color = AppColors.chipDark);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.divider
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppSizes.progressStroke,
    );
    final zoneCenter =
        center + Offset(game.zoneX * radius, game.zoneY * radius);
    canvas.drawCircle(
      zoneCenter,
      game.level.zoneRadius * radius,
      Paint()..color = AppColors.accent,
    );
    final dot =
        center + Offset(game.position.x * radius, game.position.y * radius);
    canvas.drawCircle(
      dot,
      AppSizes.stateIcon / 2,
      Paint()..color = game.isInsideZone ? AppColors.onDark : AppColors.error,
    );
  }

  @override
  bool shouldRepaint(covariant _GameBoardPainter oldDelegate) =>
      oldDelegate.game != game;
}
