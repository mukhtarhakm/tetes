import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/remote/auth_client.dart';
import '../../../data/repositories/user_repo.dart';
import '../../../data/secure/session_storage.dart';
import '../biometric/biometric_authenticator.dart';
import '../session/session_revocation_queue.dart';

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>((ref) {
  return LocalBiometricAuthenticator();
});

final authClientProvider = Provider<AuthClient>((ref) {
  final client = AuthClient();
  ref.onDispose(client.close);
  return client;
});

final sessionStorageProvider = Provider<SessionStorage>((ref) {
  return const SecureSessionStorage(FlutterSecureStorage());
});

final sessionRevocationQueueProvider = Provider<SessionRevocationQueue>((ref) {
  return SessionRevocationQueue(
    ref.watch(authClientProvider),
    ref.watch(sessionStorageProvider),
  );
});

final userRepositoryProvider = FutureProvider<UserRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return UserRepository(
    database,
    ref.watch(authClientProvider),
    ref.watch(sessionStorageProvider),
  );
});
