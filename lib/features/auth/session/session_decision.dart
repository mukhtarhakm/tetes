import '../../../data/secure/session_storage.dart';

enum SessionDecisionType { valid, missing, invalid, expired }

class SessionDecision {
  const SessionDecision._({required this.type, this.userId});

  const SessionDecision.valid(String userId)
    : this._(type: SessionDecisionType.valid, userId: userId);

  const SessionDecision.missing() : this._(type: SessionDecisionType.missing);

  const SessionDecision.invalid() : this._(type: SessionDecisionType.invalid);

  const SessionDecision.expired() : this._(type: SessionDecisionType.expired);

  final SessionDecisionType type;
  final String? userId;
}

SessionDecision decideSession(StoredSession? session, {required DateTime now}) {
  if (session == null) {
    return const SessionDecision.missing();
  }
  if (session.token.isEmpty || session.userId.isEmpty) {
    return const SessionDecision.invalid();
  }

  final expiresAt = DateTime.tryParse(session.expiresAt)?.toUtc();
  if (expiresAt == null) {
    return const SessionDecision.invalid();
  }
  if (!now.toUtc().isBefore(expiresAt)) {
    return const SessionDecision.expired();
  }

  return SessionDecision.valid(session.userId);
}
