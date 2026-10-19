import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/data/secure/session_storage.dart';
import 'package:tetes/features/auth/session/session_decision.dart';

void main() {
  final now = DateTime.utc(2026, 10, 19, 12);

  test('session tidak ada diputuskan missing', () {
    final decision = decideSession(null, now: now);

    expect(decision.type, SessionDecisionType.missing);
    expect(decision.userId, isNull);
  });

  test('session yang belum kedaluwarsa diputuskan valid dalam UTC', () {
    const session = StoredSession(
      token: 'token-rahasia',
      userId: 'user-1',
      expiresAt: '2026-10-19T19:01:00+07:00',
    );

    final decision = decideSession(session, now: now);

    expect(decision.type, SessionDecisionType.valid);
    expect(decision.userId, 'user-1');
  });

  test('session pada waktu kedaluwarsa diputuskan expired', () {
    const session = StoredSession(
      token: 'token-rahasia',
      userId: 'user-1',
      expiresAt: '2026-10-19T12:00:00Z',
    );

    final decision = decideSession(session, now: now);

    expect(decision.type, SessionDecisionType.expired);
    expect(decision.userId, isNull);
  });

  test('expires_at yang tidak dapat diparse diputuskan invalid', () {
    const session = StoredSession(
      token: 'token-rahasia',
      userId: 'user-1',
      expiresAt: 'bukan-waktu',
    );

    final decision = decideSession(session, now: now);

    expect(decision.type, SessionDecisionType.invalid);
    expect(decision.userId, isNull);
  });
}
