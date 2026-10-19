import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/remote/auth_client.dart';
import 'auth_providers.dart';

class AuthState {
  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.fieldErrors = const {},
  });

  final bool isLoading;
  final String? errorMessage;
  final Map<String, String> fieldErrors;
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
    return _submit(
      () async => (await ref.read(
        userRepositoryProvider.future,
      )).login(username: username, password: password),
    );
  }

  void clearErrors() {
    if (!state.isLoading &&
        (state.errorMessage != null || state.fieldErrors.isNotEmpty)) {
      state = const AuthState();
    }
  }

  Future<bool> _submit(Future<void> Function() operation) async {
    if (state.isLoading) {
      return false;
    }

    state = const AuthState(isLoading: true);
    try {
      await operation();
      state = const AuthState();
      return true;
    } on AuthException catch (error) {
      state = AuthState(
        errorMessage: error.message,
        fieldErrors: error.fieldErrors,
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
