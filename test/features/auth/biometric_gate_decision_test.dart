import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/auth/biometric/biometric_authenticator.dart';

void main() {
  test(
    'biometrik nonaktif melewati gerbang tanpa memeriksa perangkat',
    () async {
      final authenticator = _FakeBiometricAuthenticator(available: true);

      final decision = await decideBiometricGate(
        enabled: false,
        authenticator: authenticator,
      );

      expect(decision, BiometricGateDecision.notRequired);
      expect(authenticator.availabilityChecks, 0);
    },
  );

  test('biometrik aktif dan tersedia menampilkan gerbang', () async {
    final authenticator = _FakeBiometricAuthenticator(available: true);

    final decision = await decideBiometricGate(
      enabled: true,
      authenticator: authenticator,
    );

    expect(decision, BiometricGateDecision.authenticationRequired);
    expect(authenticator.availabilityChecks, 1);
  });

  test('biometrik aktif tetapi tidak tersedia tetap menahan gerbang', () async {
    final authenticator = _FakeBiometricAuthenticator(available: false);

    final decision = await decideBiometricGate(
      enabled: true,
      authenticator: authenticator,
    );

    expect(decision, BiometricGateDecision.unavailable);
    expect(authenticator.availabilityChecks, 1);
  });
}

class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  _FakeBiometricAuthenticator({required this.available});

  final bool available;
  int availabilityChecks = 0;

  @override
  Future<BiometricAuthenticationOutcome> authenticate() async {
    return BiometricAuthenticationOutcome.success;
  }

  @override
  Future<bool> isAvailable() async {
    availabilityChecks++;
    return available;
  }
}
