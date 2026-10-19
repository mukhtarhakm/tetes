import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_dialog.dart';
import '../../../core/ui/state_views.dart';
import '../brew_calculator.dart';
import '../brew_plan.dart';
import '../services/brew_session_hardware.dart';
import '../services/brew_stage_feedback.dart';
import '../state/brew_session_controller.dart';
import '../widgets/brew_stage_colors.dart';
import 'brew_result_placeholder_screen.dart';

const sessionUiRefreshInterval = Duration(milliseconds: 200);

enum _SessionScreenState { loading, empty, error, success }

class BrewSessionScreen extends StatefulWidget {
  const BrewSessionScreen({
    required this.plan,
    this.timeSource,
    this.shakeDetector,
    this.wakeLock,
    this.feedback,
    super.key,
  });

  final BrewPlan plan;
  final ElapsedTimeSource? timeSource;
  final BrewShakeDetector? shakeDetector;
  final BrewWakeLock? wakeLock;
  final BrewStageFeedback? feedback;

  @override
  State<BrewSessionScreen> createState() => _BrewSessionScreenState();
}

class _BrewSessionScreenState extends State<BrewSessionScreen>
    with WidgetsBindingObserver {
  _SessionScreenState _screenState = _SessionScreenState.loading;
  BrewSessionController? _controller;
  BrewShakeDetector? _shakeDetector;
  late final BrewWakeLock _wakeLock;
  late final BrewStageFeedback _feedback;
  Timer? _uiTimer;
  String? _hardwareWarning;
  bool _cancelDialogOpen = false;
  bool _leavingScreen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wakeLock = widget.wakeLock ?? const SystemBrewWakeLock();
    _feedback = widget.feedback ?? BrewStageFeedback();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _uiTimer?.cancel();
    _feedback.dispose();
    unawaited(_shakeDetector?.dispose());
    unawaited(_wakeLock.disable());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshRunningSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _leavingScreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_requestCancel());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Sesi seduh')),
        body: SafeArea(top: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    return switch (_screenState) {
      _SessionScreenState.loading => const LoadingView(
        message: 'Menyiapkan sesi seduh...',
      ),
      _SessionScreenState.empty => Padding(
        padding: AppInsets.screen,
        child: EmptyView(
          title: 'Rencana seduh kosong',
          message: 'Kembali ke Atur Seduh dan buat setidaknya satu tahap.',
          icon: Icons.format_list_numbered_rounded,
          actionLabel: 'Kembali',
          onActionPressed: () => Navigator.of(context).pop(),
        ),
      ),
      _SessionScreenState.error => Padding(
        padding: AppInsets.screen,
        child: ErrorView(
          message: 'Sesi seduh tidak dapat disiapkan.',
          onRetry: _retryInitialization,
        ),
      ),
      _SessionScreenState.success => _buildSession(),
    };
  }

  Widget _buildSession() {
    final controller = _controller!;
    final plan = controller.plan;
    final activeStage = controller.activeStage;
    final running = controller.status == BrewSessionStatus.running;
    final isLast = controller.activeStageIndex == plan.stages.length - 1;
    final activeStageColor = BrewStageColors.forPosition(activeStage.position);
    final activeStageSoftColor = BrewStageColors.softForPosition(
      activeStage.position,
    );
    return ListView(
      padding: AppInsets.screen,
      children: [
        if (_hardwareWarning case final warning?) ...[
          AppCard(variant: AppCardVariant.tinted, child: Text(warning)),
          const SizedBox(height: AppSpacing.s16),
        ],
        AppCard(
          backgroundColor: activeStageColor,
          child: Column(
            children: [
              Text(
                running ? 'Tahap aktif' : 'Siap memulai',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                activeStage.name.label,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                running
                    ? _formatCountdown(controller.countdownSeconds)
                    : _formatTime(activeStage.durationSeconds),
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                'Tuang ${_formatNumber(activeStage.targetPourG)} g • Kumulatif ${_formatNumber(plan.cumulativeWaterAt(controller.activeStageIndex))} g',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        AppCard(
          backgroundColor: activeStageSoftColor,
          child: Row(
            children: [
              const Icon(Icons.timer_outlined),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  'Waktu total',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                _formatTime(controller.elapsedSeconds),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        Text('Urutan tahap', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.s12),
        AppCard(
          child: Column(
            children: List.generate(plan.stages.length, (index) {
              final stage = plan.stages[index];
              final isActive = index == controller.activeStageIndex;
              return AnimatedContainer(
                duration: AppDurations.feedback,
                margin: EdgeInsets.only(
                  bottom: index == plan.stages.length - 1 ? 0 : AppSpacing.s8,
                ),
                padding: AppInsets.chip,
                decoration: isActive
                    ? BoxDecoration(
                        color: activeStageColor,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      )
                    : null,
                child: Row(
                  children: [
                    Container(
                      width: AppSpacing.s12,
                      height: AppSpacing.s12,
                      decoration: BoxDecoration(
                        color: BrewStageColors.forPosition(stage.position),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        stage.name.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Text(
                      '${_formatNumber(stage.targetPourG)} g',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Text(
                      _stageStatus(controller, index),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        if (!running) ...[
          Text(
            'Mulai dengan tombol atau goyangkan perangkat.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s12),
          AppButton(
            label: 'Mulai timer',
            icon: Icons.play_arrow_rounded,
            onPressed: _startManually,
          ),
        ] else
          AppButton(
            label: isLast ? 'Selesai' : 'Tahap berikutnya',
            icon: isLast
                ? Icons.check_circle_outline_rounded
                : Icons.skip_next_rounded,
            onPressed: isLast ? _finishSession : _advanceStage,
          ),
        const SizedBox(height: AppSpacing.s8),
        AppButton(
          label: 'Batalkan sesi',
          variant: AppButtonVariant.text,
          onPressed: _requestCancel,
        ),
      ],
    );
  }

  Future<void> _initialize() async {
    if (!mounted) {
      return;
    }
    try {
      if (widget.plan.stages.isEmpty) {
        setState(() => _screenState = _SessionScreenState.empty);
        return;
      }
      BrewCalculator.validatePlan(widget.plan);
      final controller = BrewSessionController(
        plan: widget.plan,
        timeSource: widget.timeSource,
      );
      final detector = widget.shakeDetector ?? BrewShakeDetector();
      detector.start(onShake: _handleShake, onError: _handleSensorError);
      setState(() {
        _controller = controller;
        _shakeDetector = detector;
        _screenState = _SessionScreenState.success;
      });
    } catch (_) {
      setState(() => _screenState = _SessionScreenState.error);
    }
  }

  void _retryInitialization() {
    unawaited(_shakeDetector?.dispose());
    _shakeDetector = null;
    setState(() {
      _screenState = _SessionScreenState.loading;
      _hardwareWarning = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  void _startManually() {
    _handleStartAction(_controller!.start());
  }

  void _handleShake() {
    if (!mounted || _controller == null) {
      return;
    }
    _handleStartAction(_controller!.handleShake());
  }

  void _handleStartAction(BrewSessionAction action) {
    if (action != BrewSessionAction.started) {
      return;
    }
    unawaited(_shakeDetector?.dispose());
    unawaited(_enableWakeLock());
    unawaited(_feedback.playTransition());
    _startUiTimer();
    setState(() {});
  }

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(
      sessionUiRefreshInterval,
      (_) => _refreshRunningSession(),
    );
  }

  void _refreshRunningSession() {
    if (!mounted || _controller?.status != BrewSessionStatus.running) {
      return;
    }
    final action = _controller!.reconcile();
    if (action == BrewSessionAction.stageAdvanced) {
      unawaited(_feedback.playTransition());
    } else if (action == BrewSessionAction.completed) {
      _uiTimer?.cancel();
      unawaited(_finishAndOpenResult());
      return;
    }
    setState(() {});
  }

  void _advanceStage() {
    final action = _controller!.nextStage();
    if (action == BrewSessionAction.stageAdvanced) {
      unawaited(_feedback.playTransition());
      setState(() {});
    } else if (action == BrewSessionAction.completed) {
      _uiTimer?.cancel();
      unawaited(_finishAndOpenResult());
    }
  }

  void _finishSession() {
    if (_controller!.finish() != BrewSessionAction.completed) {
      return;
    }
    _uiTimer?.cancel();
    unawaited(_finishAndOpenResult());
  }

  Future<void> _finishAndOpenResult() async {
    if (_leavingScreen) {
      return;
    }
    _leavingScreen = true;
    await _feedback.playCompleted();
    await _completeAndOpenResult();
  }

  Future<void> _completeAndOpenResult() async {
    await _disableWakeLock();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) =>
            BrewResultPlaceholderScreen(result: _controller!.result!),
      ),
    );
  }

  Future<void> _requestCancel() async {
    if (_cancelDialogOpen || _leavingScreen || !mounted) {
      return;
    }
    _cancelDialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Batalkan sesi?',
        message: 'Waktu yang sudah dicatat akan dibuang.',
        primaryLabel: 'Batalkan sesi',
        onPrimaryPressed: () => Navigator.of(dialogContext).pop(true),
        secondaryLabel: 'Lanjut seduh',
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(false),
      ),
    );
    _cancelDialogOpen = false;
    if (confirmed != true || !mounted) {
      return;
    }
    _controller?.cancel();
    _feedback.cancel();
    _uiTimer?.cancel();
    await _disableWakeLock();
    if (mounted) {
      setState(() => _leavingScreen = true);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _enableWakeLock() async {
    try {
      await _wakeLock.enable();
    } catch (_) {
      _showHardwareWarning(
        'Layar tidak dapat dipertahankan tetap menyala. Timer tetap berjalan.',
      );
    }
  }

  Future<void> _disableWakeLock() async {
    try {
      await _wakeLock.disable();
    } catch (_) {
      // Tidak ada tindakan pemulihan saat sesi sudah berakhir atau dibatalkan.
    }
  }

  void _handleSensorError(Object _) {
    _showHardwareWarning(
      'Sensor goyang tidak tersedia. Gunakan tombol Mulai timer.',
    );
  }

  void _showHardwareWarning(String message) {
    if (mounted) {
      setState(() => _hardwareWarning = message);
    }
  }
}

String _stageStatus(BrewSessionController controller, int index) {
  if (index < controller.activeStageIndex) {
    return 'Selesai';
  }
  if (index == controller.activeStageIndex) {
    return controller.status == BrewSessionStatus.running ? 'Aktif' : 'Siap';
  }
  return 'Berikutnya';
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

String _formatCountdown(int seconds) {
  return _formatTime(seconds < 0 ? 0 : seconds);
}

String _formatTime(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
