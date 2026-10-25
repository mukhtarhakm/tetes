import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../data/remote/auth_client.dart';
import '../biometric/biometric_authenticator.dart';
import 'auth_providers.dart';
import 'session_controller.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.fieldErrors = const {},
    this.requiresLogin = false,
  });

  final bool isLoading;
  final String? errorMessage;
  final Map<String, String> fieldErrors;
  final bool requiresLogin;
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<bool> register({required String username, required String password}) {
    return _submit(
      () async => (await ref.read(
        userRepositoryProvider.future,
      )).register(username: username, password: password),
    );
  }

  Future<bool> login({required String username, required String password}) {
    return _submit(() async {
      await ref
          .read(sessionRevocationQueueProvider)
          .retryPending(totalTimeout: AppConfig.pendingRevokeRetryTimeout);
      return (await ref.read(
        userRepositoryProvider.future,
      )).login(username: username, password: password);
    }, offerBiometric: true);
  }

  Future<bool> loginBiometric(String username) async {
    if (state.isLoading) return false;
    state = const AuthState(isLoading: true);
    final outcome = await ref
        .read(biometricAuthenticatorProvider)
        .authenticate();
    if (outcome != BiometricAuthenticationOutcome.success) {
      state = AuthState(
        errorMessage: switch (outcome) {
          BiometricAuthenticationOutcome.canceled =>
            'Pemeriksaan sidik jari dibatalkan.',
          BiometricAuthenticationOutcome.lockedOut =>
            'Sidik jari sedang dikunci oleh sistem. Coba lagi nanti.',
          BiometricAuthenticationOutcome.unavailable =>
            'Sidik jari tidak tersedia. Masuk dengan password.',
          _ =>
            'Sidik jari tidak dikenali. Coba lagi atau masuk dengan password.',
        },
      );
      return false;
    }
    state = const AuthState();
    return _submit(
      () async => (await ref.read(
        userRepositoryProvider.future,
      )).loginBiometric(username),
    );
  }

  void clearErrors() {
    if (!state.isLoading &&
        (state.errorMessage != null || state.fieldErrors.isNotEmpty)) {
      state = const AuthState();
    }
  }

  Future<bool> _submit(Future<String> Function() operation,
      {bool offerBiometric = false}) async {
    if (state.isLoading) {
      return false;
    }

    state = const AuthState(isLoading: true);
    try {
      final userId = await operation();
      ref.read(sessionControllerProvider.notifier)
          .markAuthenticated(userId, offerBiometric: offerBiometric);
      state = const AuthState();
      return true;
    } on AuthException catch (error) {
      state = AuthState(
        errorMessage: error.message,
        fieldErrors: error.fieldErrors,
        requiresLogin: error.message == 'Akun dibuat. Silakan masuk.',
      );
      return false;
    } catch (_) {
      state = const AuthState(
        errorMessage: 'Autentikasi gagal. Silakan coba lagi.',
      );
      return false;
    }
  }
}
