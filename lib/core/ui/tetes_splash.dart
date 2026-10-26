import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import 'tetes_logo.dart';

/// Layar pembuka saat aplikasi memeriksa sesi: logo besar, nama, tagline,
/// dan tiga titik berdenyut di bawah.
class TetesSplash extends StatelessWidget {
  const TetesSplash({this.message = 'Memeriksa sesi...', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Semantics(
          liveRegion: true,
          label: message,
          child: Column(
            children: [
              const Spacer(flex: 5),
              const TetesLogo(size: 104),
              const SizedBox(height: AppSpacing.s20),
              Text(
                'Tetes',
                style: textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                'Jurnal seduh V60',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
              const Spacer(flex: 4),
              const _PulseDots(),
              const SizedBox(height: AppSpacing.s48),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulseDots extends StatefulWidget {
  const _PulseDots();

  @override
  State<_PulseDots> createState() => _PulseDotsState();
}

class _PulseDotsState extends State<_PulseDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.s8),
              _dot(i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dot(int index) {
    // Tiap titik menyala bergiliran: cyan penuh lalu memudar.
    final phase = (_controller.value - index / 3) % 1.0;
    final strength = phase < 0.5 ? 1 - phase * 2 : 0.0;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(AppColors.divider, AppColors.primary, strength),
      ),
    );
  }
}
