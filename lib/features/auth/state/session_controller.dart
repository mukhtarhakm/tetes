import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../data/repositories/chain_anchor_repo.dart';

import '../session/session_decision.dart';
import '../session/session_revocation_queue.dart';
import 'auth_providers.dart';

enum SessionStatus { authenticated, unauthenticated }

class SessionState {
  const SessionState._({
    required this.status,
    this.userId,
    this.message,
    this.isFreshAuthentication = false,
    this.offerBiometric = false,
  });

  const SessionState.authenticated(
    String userId, {
    bool isFreshAuthentication = false,
    bool offerBiometric = false,
  }) : this._(
         status: SessionStatus.authenticated,
         userId: userId,
         isFreshAuthentication: isFreshAuthentication,
         offerBiometric: offerBiometric,
       );

  const SessionState.unauthenticated({String? message})
    : this._(status: SessionStatus.unauthenticated, message: message);

  final SessionStatus status;
  final String? userId;
  final String? message;
  final bool isFreshAuthentication;
  final bool offerBiometric;
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
    final pendingTokens = await storage.readPendingRevokeTokens();
    final interruptedLogout =
        storedSession != null && pendingTokens.contains(storedSession.token);
    if (interruptedLogout) {
      await storage.clearSession();
    }
    unawaited(ref.watch(sessionRevocationQueueProvider).retryPending());
    if (interruptedLogout) {
      return const SessionState.unauthenticated(
        message:
            'Kamu sudah keluar. Sesi di server akan dicabut saat tersambung.',
      );
    }
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

  void markAuthenticated(String userId, {bool offerBiometric = false}) {
    state = AsyncData(
      SessionState.authenticated(userId,
          isFreshAuthentication: true, offerBiometric: offerBiometric),
    );
  }

  Future<void> logout() async {
    final storage = ref.read(sessionStorageProvider);
    final storedSession = await storage.readSession();
    final token = storedSession?.token;

    if (token != null) {
      await ref.read(sessionRevocationQueueProvider).enqueue(token);
    }
    await ref.read(notificationServiceProvider).cancelAll();
    if (storedSession != null) {
      await ref.read(clearChainAnchorsProvider)(storedSession.userId);
    }
    await storage.clearSession();
    state = const AsyncData(
      SessionState.unauthenticated(message: 'Kamu sudah keluar.'),
    );

    if (token != null) {
      unawaited(_finishLogoutRevocation(token));
    }
  }

  Future<void> forceLogout() async {
    try {
      try {
        await ref.read(notificationServiceProvider).cancelAll();
      } finally {
        try {
          final session = await ref.read(sessionStorageProvider).readSession();
          if (session != null) {
            await ref.read(clearChainAnchorsProvider)(session.userId);
          }
        } finally {
          await ref.read(sessionStorageProvider).clearSession();
        }
      }
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

  Future<void> _finishLogoutRevocation(String token) async {
    final result = await ref
        .read(sessionRevocationQueueProvider)
        .revokeQueuedToken(token);
    if (result != RevocationResult.deferred) {
      return;
    }

    final current = state.asData?.value;
    if (current?.status == SessionStatus.unauthenticated) {
      state = const AsyncData(
        SessionState.unauthenticated(
          message:
              'Kamu sudah keluar. Sesi di server akan dicabut saat tersambung.',
        ),
      );
    }
  }
}
