import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_shell.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/state_views.dart';
import '../biometric/biometric_authenticator.dart';
import '../state/auth_providers.dart';
import '../state/session_controller.dart';

class BiometricGateScreen extends ConsumerStatefulWidget {
  const BiometricGateScreen({required this.biometricAvailable, super.key});

  final bool biometricAvailable;

  @override
  ConsumerState<BiometricGateScreen> createState() =>
      _BiometricGateScreenState();
}

class _BiometricGateScreenState extends ConsumerState<BiometricGateScreen> {
  bool _automaticAttemptStarted = false;
  bool _isAuthenticating = false;
  bool _isLoggingOut = false;
  bool _unlocked = false;
  late bool _canRetry;
  String? _message;

  @override
  void initState() {
    super.initState();
    _canRetry = widget.biometricAvailable;
    if (widget.biometricAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _automaticAttemptStarted) {
          return;
        }
        _automaticAttemptStarted = true;
        _authenticate();
      });
    } else {
      _message =
          'Biometrik tidak tersedia atau tidak lagi terdaftar. Gunakan password untuk masuk kembali.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) {
      return const AppShell();
    }

    if (_isAuthenticating) {
      return const Scaffold(
        body: SafeArea(
          child: LoadingView(message: 'Menunggu pemeriksaan biometrik...'),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppInsets.screen,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: AppSizes.stateIconContainer,
                  height: AppSizes.stateIconContainer,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: AppSizes.stateIcon,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  'Buka Tetes',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  _message ?? 'Gunakan biometrik untuk membuka aplikasi.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.inkSoft),
                  textAlign: TextAlign.center,
                ),
                if (_canRetry) ...[
                  const SizedBox(height: AppSpacing.s24),
                  AppButton(
                    label: 'Coba lagi',
                    onPressed: _isLoggingOut ? null : _authenticate,
                  ),
                ],
                const SizedBox(height: AppSpacing.s8),
                AppButton(
                  label: 'Pakai password',
                  variant: AppButtonVariant.text,
                  isLoading: _isLoggingOut,
                  onPressed: _isLoggingOut ? null : _usePassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating || _isLoggingOut) {
      return;
    }
    setState(() {
      _isAuthenticating = true;
      _message = null;
    });

    final outcome = await ref
        .read(biometricAuthenticatorProvider)
        .authenticate();
    if (!mounted) {
      return;
    }

    switch (outcome) {
      case BiometricAuthenticationOutcome.success:
        setState(() {
          _isAuthenticating = false;
          _unlocked = true;
        });
        return;
      case BiometricAuthenticationOutcome.failed:
        _showFailure(
          'Biometrik tidak dikenali. Coba lagi atau pakai password.',
        );
        return;
      case BiometricAuthenticationOutcome.canceled:
        _showFailure(
          'Pemeriksaan biometrik dibatalkan. Coba lagi atau pakai password.',
        );
        return;
      case BiometricAuthenticationOutcome.lockedOut:
        _showFailure(
          'Biometrik dikunci oleh sistem. Coba lagi nanti atau pakai password.',
        );
        return;
      case BiometricAuthenticationOutcome.unavailable:
        setState(() {
          _isAuthenticating = false;
          _canRetry = false;
          _message =
              'Biometrik tidak tersedia atau tidak lagi terdaftar. Gunakan password untuk masuk kembali.';
        });
        return;
      case BiometricAuthenticationOutcome.error:
        _showFailure(
          'Biometrik tidak dapat diperiksa. Coba lagi atau pakai password.',
        );
        return;
    }
  }

  void _showFailure(String message) {
    setState(() {
      _isAuthenticating = false;
      _message = message;
    });
  }

  Future<void> _usePassword() async {
    if (_isLoggingOut) {
      return;
    }
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await ref.read(sessionControllerProvider.notifier).logout();
      AppRouter.navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.home,
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
          _message = 'Tidak dapat kembali ke login. Silakan coba lagi.';
        });
      }
    }
  }
}
