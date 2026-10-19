import '../../../core/config/app_config.dart';
import '../../../data/remote/auth_client.dart';
import '../../../data/secure/session_storage.dart';

enum RevocationResult { revoked, deferred, nothingPending }

class SessionRevocationQueue {
  SessionRevocationQueue(this._client, this._storage);

  static const maxPendingTokens = 5;

  final SessionRevocationClient _client;
  final SessionStorage _storage;
  final Set<String> _inFlightTokens = {};
  Future<void> _queueOperation = Future.value();

  Future<void> enqueue(String token) {
    return _withQueueLock(() async {
      final current = await _storage.readPendingRevokeTokens();
      final updated = [...current.where((item) => item != token), token];
      final bounded = updated.length <= maxPendingTokens
          ? updated
          : updated.sublist(updated.length - maxPendingTokens);
      await _storage.writePendingRevokeTokens(bounded);
    });
  }

  Future<RevocationResult> revokeQueuedToken(
    String token, {
    Duration? requestTimeout,
  }) async {
    if (!_inFlightTokens.add(token)) {
      return RevocationResult.deferred;
    }

    try {
      await _client.revokeSession(token: token, requestTimeout: requestTimeout);
      await _remove(token);
      return RevocationResult.revoked;
    } catch (_) {
      return RevocationResult.deferred;
    } finally {
      _inFlightTokens.remove(token);
    }
  }

  Future<RevocationResult> retryPending({
    Duration totalTimeout = AppConfig.authRequestTimeout,
  }) async {
    late List<String> tokens;
    try {
      tokens = await _withQueueLock(_storage.readPendingRevokeTokens);
    } catch (_) {
      return RevocationResult.deferred;
    }
    if (tokens.isEmpty) {
      return RevocationResult.nothingPending;
    }

    final stopwatch = Stopwatch()..start();
    var result = RevocationResult.revoked;
    for (final token in tokens) {
      final remaining = totalTimeout - stopwatch.elapsed;
      if (remaining <= Duration.zero) {
        return RevocationResult.deferred;
      }
      final tokenResult = await revokeQueuedToken(
        token,
        requestTimeout: remaining,
      );
      if (tokenResult != RevocationResult.revoked) {
        result = RevocationResult.deferred;
      }
    }
    return result;
  }

  Future<void> _remove(String token) {
    return _withQueueLock(() async {
      final current = await _storage.readPendingRevokeTokens();
      await _storage.writePendingRevokeTokens(
        current.where((item) => item != token).toList(growable: false),
      );
    });
  }

  Future<T> _withQueueLock<T>(Future<T> Function() operation) {
    final result = _queueOperation.then((_) => operation());
    _queueOperation = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }
}
