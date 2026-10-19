import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_decision.dart';
import 'auth_providers.dart';

enum SessionStatus { authenticated, unauthenticated }

class SessionState {
  const SessionState._({required this.status, this.userId, this.message});

  const SessionState.authenticated(String userId)
    : this._(status: SessionStatus.authenticated, userId: userId);

  const SessionState.unauthenticated({String? message})
    : this._(status: SessionStatus.unauthenticated, message: message);

  final SessionStatus status;
  final String? userId;
  final String? message;
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
      SessionController.new,
    );

class SessionController extends AsyncNotifier<SessionState> {
  @override
  Future<SessionState> build() async {
    final storage = ref.watch(sessionStorageProvider);
    final storedSession = await storage.readSession();
    final decision = decideSession(storedSession, now: DateTime.now().toUtc());

    return switch (decision.type) {
      SessionDecisionType.valid => SessionState.authenticated(decision.userId!),
      SessionDecisionType.missing => const SessionState.unauthenticated(),
      SessionDecisionType.invalid => _clearInvalidSession(
        message: 'Sesi tidak valid. Silakan masuk kembali.',
      ),
      SessionDecisionType.expired => _clearInvalidSession(
        message:
            'Sesi telah berakhir. Internet diperlukan untuk masuk kembali.',
      ),
    };
  }

  void markAuthenticated(String userId) {
    state = AsyncData(SessionState.authenticated(userId));
  }

  Future<void> forceLogout() async {
    try {
      await ref.read(sessionStorageProvider).clearSession();
    } finally {
      state = const AsyncData(
        SessionState.unauthenticated(
          message: 'Sesi berakhir, silakan masuk lagi',
        ),
      );
    }
  }

  Future<SessionState> _clearInvalidSession({required String message}) async {
    await ref.read(sessionStorageProvider).clearSession();
    return SessionState.unauthenticated(message: message);
  }
}
