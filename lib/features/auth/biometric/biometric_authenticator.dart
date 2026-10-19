import 'package:local_auth/local_auth.dart';

enum BiometricAuthenticationOutcome {
  success,
  failed,
  canceled,
  lockedOut,
  unavailable,
  error,
}

enum BiometricGateDecision { notRequired, authenticationRequired, unavailable }

abstract interface class BiometricAuthenticator {
  Future<bool> isAvailable();

  Future<BiometricAuthenticationOutcome> authenticate();
}

class LocalBiometricAuthenticator implements BiometricAuthenticator {
  LocalBiometricAuthenticator({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<bool> isAvailable() async {
    try {
      final hasHardware = await _localAuthentication.canCheckBiometrics;
      if (!hasHardware) {
        return false;
      }
      final enrolledBiometrics = await _localAuthentication
          .getAvailableBiometrics();
      return enrolledBiometrics.isNotEmpty;
    } on LocalAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BiometricAuthenticationOutcome> authenticate() async {
    if (!await isAvailable()) {
      return BiometricAuthenticationOutcome.unavailable;
    }

    try {
      final authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Buka aplikasi Tetes dengan biometrik',
        biometricOnly: true,
        persistAcrossBackgrounding: false,
      );
      return authenticated
          ? BiometricAuthenticationOutcome.success
          : BiometricAuthenticationOutcome.failed;
    } on LocalAuthException catch (error) {
      if (error.code == LocalAuthExceptionCode.noBiometricHardware ||
          error.code == LocalAuthExceptionCode.noBiometricsEnrolled ||
          error.code == LocalAuthExceptionCode.noCredentialsSet ||
          error.code ==
              LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable) {
        return BiometricAuthenticationOutcome.unavailable;
      }
      if (error.code == LocalAuthExceptionCode.temporaryLockout ||
          error.code == LocalAuthExceptionCode.biometricLockout) {
        return BiometricAuthenticationOutcome.lockedOut;
      }
      if (error.code == LocalAuthExceptionCode.userCanceled ||
          error.code == LocalAuthExceptionCode.systemCanceled ||
          error.code == LocalAuthExceptionCode.userRequestedFallback) {
        return BiometricAuthenticationOutcome.canceled;
      }
      return BiometricAuthenticationOutcome.error;
    } catch (_) {
      return BiometricAuthenticationOutcome.error;
    }
  }
}

Future<BiometricGateDecision> decideBiometricGate({
  required bool enabled,
  required BiometricAuthenticator authenticator,
}) async {
  if (!enabled) {
    return BiometricGateDecision.notRequired;
  }

  return await authenticator.isAvailable()
      ? BiometricGateDecision.authenticationRequired
      : BiometricGateDecision.unavailable;
}
