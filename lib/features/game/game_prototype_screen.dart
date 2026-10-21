import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_chip.dart';
import '../../core/ui/focus_dark_theme.dart';
import '../../core/ui/state_views.dart';
import '../../data/repositories/game_repo.dart';
import '../auth/state/session_controller.dart';
import 'game_prototype_controller.dart';
import 'game_orientation_lock.dart';
import 'game_tutorial_screen.dart';
import 'steady_pour_control.dart';
import 'steady_pour_game.dart';
import 'widgets/game_board.dart';

class GamePrototypeScreen extends ConsumerStatefulWidget {
  const GamePrototypeScreen({super.key});

  @override
  ConsumerState<GamePrototypeScreen> createState() =>
      _GamePrototypeScreenState();
}

class _GamePrototypeScreenState extends ConsumerState<GamePrototypeScreen>
    with WidgetsBindingObserver {
  GamePrototypeController? _controller;
  late final GameOrientationLock _orientationLock;
  GameRepository? _repository;
  String? _userId;
  bool _loading = true;
  bool _inForeground = true;
  bool _showTutorial = false;
  bool _manualTutorial = false;
  bool _savingTutorial = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _orientationLock = GameOrientationLock()..lockPortrait();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final userId = ref.read(sessionControllerProvider).asData?.value.userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final repository = await ref.read(gameRepositoryProvider.future);
      if (!mounted) return;
      final tutorialSeen = await repository.hasSeenTutorial(userId);
      if (!mounted) return;
      _repository = repository;
      _userId = userId;
      if (tutorialSeen) {
        await _openGame(repository, userId);
        return;
      }
      setState(() {
        _showTutorial = true;
        _manualTutorial = false;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Game tidak dapat dibuka. Coba lagi.';
        });
      }
    }
  }

  Future<void> _openGame(GameRepository repository, String userId) async {
    final controller = GamePrototypeController(
      userId: userId,
      repository: repository,
    );
    await controller.initialize();
    if (!_inForeground) controller.pause();
    if (!mounted) {
      controller.dispose();
      return;
    }
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    controller.addListener(_refresh);
    setState(() {
      _controller = controller;
      _showTutorial = false;
      _loading = false;
    });
  }

  Future<void> _understoodTutorial() async {
    if (_savingTutorial) return;
    if (_manualTutorial) {
      setState(() => _showTutorial = false);
      _controller?.resume();
      return;
    }
    final repository = _repository;
    final userId = _userId;
    if (repository == null || userId == null) return;
    setState(() => _savingTutorial = true);
    try {
      await repository.markTutorialSeen(userId);
      if (!mounted) return;
      setState(() {
        _savingTutorial = false;
        _loading = true;
      });
      await _openGame(repository, userId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingTutorial = false;
        _showTutorial = false;
        _loading = false;
        _error = 'Cara main tidak dapat disimpan. Coba lagi.';
      });
    }
  }

  void _openTutorial() {
    _controller?.pause();
    setState(() {
      _manualTutorial = true;
      _showTutorial = true;
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _inForeground = state == AppLifecycleState.resumed;
    if (_inForeground) {
      _orientationLock.lockPortrait();
    } else {
      _orientationLock.restoreAppOrientation();
      _controller?.pause();
    }
    if (_showTutorial && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _orientationLock.dispose();
    _controller?.removeListener(_refresh);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FocusDarkTheme(
    child: Builder(
      builder: (darkContext) => Scaffold(
        appBar: AppBar(title: const Text('Steady Pour')),
        body: SafeArea(child: _buildBody(darkContext)),
      ),
    ),
  );

  Widget _buildBody(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Menyiapkan gyroscope...');
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _initialize);
    }
    if (_showTutorial) {
      return GameTutorialScreen(
        active: _inForeground,
        isSaving: _savingTutorial,
        onUnderstood: _understoodTutorial,
      );
    }
    final controller = _controller;
    if (controller == null) {
      return EmptyView(
        title: 'Sesi tidak tersedia',
        message: 'Masuk kembali untuk mencoba game.',
        actionLabel: 'Kembali',
        onActionPressed: () => Navigator.of(context).pop(),
      );
    }
    if (controller.phase == GamePrototypePhase.unavailable) {
      return ErrorView(
        message: controller.unavailableMessage,
        onRetry: () {
          _controller?.removeListener(_refresh);
          _controller?.dispose();
          _controller = null;
          _initialize();
        },
      );
    }
    return switch (controller.phase) {
      GamePrototypePhase.loading => const LoadingView(
        message: 'Menyiapkan game...',
      ),
      GamePrototypePhase.selection => _buildSelection(context, controller),
      GamePrototypePhase.calibration => _buildCalibration(context, controller),
      GamePrototypePhase.countdown ||
      GamePrototypePhase.playing => _buildPlaying(context, controller),
      GamePrototypePhase.paused => _buildPaused(context, controller),
      GamePrototypePhase.saving => const LoadingView(
        message: 'Menyimpan skor...',
      ),
      GamePrototypePhase.result => _buildResult(context, controller),
      GamePrototypePhase.saveError => ErrorView(
        message: 'Skor belum tersimpan. Coba simpan lagi.',
        onRetry: controller.retrySave,
      ),
      GamePrototypePhase.unavailable => const SizedBox.shrink(),
    };
  }

  Widget _buildSelection(
    BuildContext context,
    GamePrototypeController controller,
  ) => ListView(
    padding: AppInsets.screen,
    children: [
      Text('Pilih level', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: AppSpacing.s16),
      AppButton(
        label: 'Cara main',
        variant: AppButtonVariant.secondary,
        onPressed: _openTutorial,
      ),
      const SizedBox(height: AppSpacing.s16),
      for (final level in gameLevels) ...[
        _buildLevelCard(context, controller, level),
        const SizedBox(height: AppSpacing.s12),
      ],
      const SizedBox(height: AppSpacing.s24),
      Text('Sensitivitas', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppSpacing.s12),
      Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: [
          for (final value in GameSensitivity.values)
            AppChip(
              label: value.label,
              selected: controller.sensitivity == value,
              onSelected: (_) => controller.setSensitivity(value),
            ),
        ],
      ),
    ],
  );

  Widget _buildLevelCard(
    BuildContext context,
    GamePrototypeController controller,
    GameLevel level,
  ) {
    final unlocked = controller.isUnlocked(level.number);
    final best = controller.bestScores[level.number];
    return AppCard(
      backgroundColor: AppColors.surface,
      child: Builder(
        builder: (cardContext) => InkWell(
          onTap: unlocked ? () => controller.selectLevel(level) : null,
          child: Row(
            children: [
              Icon(unlocked ? Icons.play_circle_outline : Icons.lock_outline),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Level ${level.number} · ${level.name}',
                      style: Theme.of(cardContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      best == null
                          ? unlocked
                                ? 'Belum ada skor'
                                : 'Selesaikan level sebelumnya'
                          : '${'★' * best.stars} · Akurasi terbaik ${(best.accuracy * 100).round()}%',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalibration(
    BuildContext context,
    GamePrototypeController controller,
  ) => ListView(
    padding: AppInsets.screen,
    children: [
      Text(
        'Kalibrasi · ${controller.game!.level.name}',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: AppSpacing.s16),
      Text(
        'Pegang HP datar, lalu ketuk Mulai.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: AppSpacing.s24),
      GameBoard(game: controller.game!),
      const SizedBox(height: AppSpacing.s24),
      AppButton(label: 'Mulai', onPressed: controller.calibrateAndStart),
      AppButton(
        label: 'Pilih level',
        variant: AppButtonVariant.text,
        onPressed: controller.returnToSelection,
      ),
    ],
  );

  Widget _buildPlaying(
    BuildContext context,
    GamePrototypeController controller,
  ) {
    final game = controller.game!;
    final counting = controller.phase == GamePrototypePhase.countdown;
    return ListView(
      padding: AppInsets.screen,
      children: [
        Text(
          game.level.name,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          counting
              ? '${controller.countdownSeconds.ceil()}'
              : '${game.remainingSeconds.ceil()} dtk',
          style: Theme.of(context).textTheme.displayLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s16),
        GameBoard(game: game),
        const SizedBox(height: AppSpacing.s16),
        Text(
          game.isInsideZone ? 'Di dalam zona' : 'Di luar zona',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (game.level.number == 1) ...[
          const SizedBox(height: AppSpacing.s8),
          Visibility(
            visible:
                !counting &&
                game.elapsedSeconds < levelOneHintDuration.inSeconds,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Text(
              'Miringkan HP ke arah zona hijau',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s8),
        LinearProgressIndicator(
          value: game.waterProgress,
          minHeight: AppSpacing.s12,
          color: AppColors.primary,
          backgroundColor: AppColors.chipDark,
        ),
        const SizedBox(height: AppSpacing.s24),
        AppButton(label: 'Jeda', onPressed: controller.pause),
      ],
    );
  }

  Widget _buildPaused(
    BuildContext context,
    GamePrototypeController controller,
  ) => ListView(
    padding: AppInsets.screen,
    children: [
      Text('Dijeda', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: AppSpacing.s16),
      Text(
        'Ketuk Lanjut untuk kalibrasi ulang.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: AppSpacing.s24),
      AppButton(label: 'Lanjut', onPressed: controller.resume),
      if (controller.game != null)
        AppButton(
          label: 'Pilih level',
          variant: AppButtonVariant.text,
          onPressed: controller.returnToSelection,
        ),
    ],
  );

  Widget _buildResult(
    BuildContext context,
    GamePrototypeController controller,
  ) {
    final game = controller.game!;
    final won = game.outcome == GameOutcome.completed;
    return ListView(
      padding: AppInsets.screen,
      children: [
        Text(
          won ? 'Berhasil!' : 'Waktu habis',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.s16),
        Text(
          won
              ? 'Akurasi ${(game.accuracy * 100).round()}% · ${'★' * game.stars}'
              : 'Coba jaga titik lebih lama di dalam zona.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.s24),
        AppButton(
          label: won ? 'Ulangi' : 'Coba lagi',
          onPressed: controller.retryLevel,
        ),
        if (won && game.level.number < gameLevels.length) ...[
          const SizedBox(height: AppSpacing.s12),
          AppButton(label: 'Level berikutnya', onPressed: controller.nextLevel),
        ],
        const SizedBox(height: AppSpacing.s12),
        AppButton(
          label: 'Pilih level',
          variant: AppButtonVariant.text,
          onPressed: controller.returnToSelection,
        ),
      ],
    );
  }
}
