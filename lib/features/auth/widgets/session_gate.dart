import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation/app_shell.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/ui/state_views.dart';
import '../screens/login_screen.dart';
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
        SessionStatus.authenticated =>
          state.offerBiometric
              ? PostAuthBiometricOffer(
                  userId: state.userId!,
                  child: const AppShell(),
                )
              : const AppShell(),
        SessionStatus.unauthenticated => LoginScreen(
          sessionMessage: state.message,
        ),
      },
    );
  }
}
