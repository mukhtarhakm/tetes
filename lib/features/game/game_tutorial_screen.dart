import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../../core/ui/app_button.dart';

const tutorialAnimationDuration = Duration(seconds: 4);
const tutorialTiltRadians = 0.28;
const tutorialPerspective = 0.001;
const tutorialDotTravel = 0.65;

class GameTutorialScreen extends StatefulWidget {
  const GameTutorialScreen({
    required this.active,
    required this.onUnderstood,
    this.isSaving = false,
    super.key,
  });

  final bool active;
  final bool isSaving;
  final VoidCallback onUnderstood;

  @override
  State<GameTutorialScreen> createState() => _GameTutorialScreenState();
}

class _GameTutorialScreenState extends State<GameTutorialScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: tutorialAnimationDuration,
  );
  late final Animation<Offset> _movement = TweenSequence<Offset>([
    TweenSequenceItem(
      tween: Tween(begin: Offset.zero, end: const Offset(1, 0)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: const Offset(1, 0), end: Offset.zero),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: Offset.zero, end: const Offset(0, -1)),
      weight: 1,
    ),
    TweenSequenceItem(
      tween: Tween(begin: const Offset(0, -1), end: Offset.zero),
      weight: 1,
    ),
  ]).animate(CurvedAnimation(parent: _animation, curve: Curves.easeInOut));

  @override
  void initState() {
    super.initState();
    if (widget.active) _animation.repeat();
  }

  @override
  void didUpdateWidget(covariant GameTutorialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _animation.repeat();
    if (!widget.active && oldWidget.active) _animation.stop();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: AppInsets.screen,
    children: [
      Text('Cara main', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: AppSpacing.s24),
      SizedBox(
        height: AppSizes.statePreviewHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.chipDark,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: AnimatedBuilder(
            animation: _movement,
            builder: (context, _) {
              final direction = _movement.value;
              final tilt = Matrix4.identity()
                ..setEntry(3, 2, tutorialPerspective)
                ..rotateY(-direction.dx * tutorialTiltRadians)
                ..rotateX(direction.dy * tutorialTiltRadians);
              return Stack(
                children: [
                  Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: tilt,
                      child: const Icon(
                        Icons.smartphone_rounded,
                        size: AppSizes.stateIconContainer,
                        color: AppColors.onDark,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(
                      direction.dx * tutorialDotTravel,
                      direction.dy * tutorialDotTravel,
                    ),
                    child: const Icon(
                      Icons.circle,
                      size: AppSizes.stateIcon,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.s24),
      Text(
        'Pegang HP datar seperti memegang piring.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: AppSpacing.s12),
      Text(
        'Miringkan HP ke arah zona hijau.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: AppSpacing.s12),
      Text(
        'Jaga titik tetap di dalam zona sampai bar penuh.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: AppSpacing.s24),
      AppButton(
        label: 'Mengerti',
        isLoading: widget.isSaving,
        onPressed: widget.onUnderstood,
      ),
    ],
  );
}
