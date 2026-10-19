import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_shell.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/state_views.dart';
import '../biometric/biometric_authenticator.dart';
import '../screens/biometric_gate_screen.dart';
import '../screens/login_screen.dart';
import '../state/auth_providers.dart';
import '../state/session_controller.dart';
import 'post_auth_biometric_offer.dart';

class SessionGate extends ConsumerWidget {
  const SessionGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);

    return session.when(
      loading: () =>
          const Scaffold(body: LoadingView(message: 'Memeriksa sesi...')),
      error: (_, _) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: AppInsets.screen,
            child: ErrorView(
              message:
                  'Sesi tidak dapat dibaca dengan aman. Silakan coba lagi.',
              onRetry: () => ref.invalidate(sessionControllerProvider),
            ),
          ),
        ),
      ),
      data: (state) => switch (state.status) {
        SessionStatus.authenticated => _AuthenticatedSessionGate(
          key: ValueKey(state.userId),
          userId: state.userId!,
          isFreshAuthentication: state.isFreshAuthentication,
        ),
        SessionStatus.unauthenticated => LoginScreen(
          sessionMessage: state.message,
        ),
      },
    );
  }
}

class _AuthenticatedSessionGate extends ConsumerStatefulWidget {
  const _AuthenticatedSessionGate({
    required this.userId,
    required this.isFreshAuthentication,
    super.key,
  });

  final String userId;
  final bool isFreshAuthentication;

  @override
  ConsumerState<_AuthenticatedSessionGate> createState() =>
      _AuthenticatedSessionGateState();
}

class _AuthenticatedSessionGateState
    extends ConsumerState<_AuthenticatedSessionGate> {
  late final Future<BiometricGateDecision> _gateDecision;

  @override
  void initState() {
    super.initState();
    _gateDecision = widget.isFreshAuthentication
        ? Future.value(BiometricGateDecision.notRequired)
        : _resolveGateDecision();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFreshAuthentication) {
      return PostAuthBiometricOffer(
        userId: widget.userId,
        child: const AppShell(),
      );
    }

    return FutureBuilder<BiometricGateDecision>(
      future: _gateDecision,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: LoadingView(message: 'Memeriksa pengaturan biometrik...'),
          );
        }

        final decision = snapshot.hasError
            ? BiometricGateDecision.unavailable
            : snapshot.requireData;
        return switch (decision) {
          BiometricGateDecision.notRequired => const AppShell(),
          BiometricGateDecision.authenticationRequired =>
            const BiometricGateScreen(biometricAvailable: true),
          BiometricGateDecision.unavailable => const BiometricGateScreen(
            biometricAvailable: false,
          ),
        };
      },
    );
  }

  Future<BiometricGateDecision> _resolveGateDecision() async {
    final repository = await ref.read(userRepositoryProvider.future);
    final enabled = await repository.isBiometricEnabled(widget.userId);
    return decideBiometricGate(
      enabled: enabled,
      authenticator: ref.read(biometricAuthenticatorProvider),
    );
  }
}
