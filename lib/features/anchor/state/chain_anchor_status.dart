import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/remote/anchor_client.dart';
import '../../../data/remote/chain_verifier.dart';
import '../../../data/repositories/brew_repo.dart';
import '../../../data/repositories/chain_anchor_repo.dart';
import '../../auth/state/auth_providers.dart';
import '../../auth/state/session_controller.dart';
import '../../brew/state/brew_setup_controller.dart';

enum ChainAnchorPhase { noBrews, unanchored, pending, confirmed, failed }

class ChainAnchorStatus {
  const ChainAnchorStatus(this.phase, {this.anchor, this.message});
  final ChainAnchorPhase phase;
  final ChainAnchorRecord? anchor;
  final String? message;
}

final anchorClientProvider = Provider<AnchorClient>((ref) {
  final client = AnchorClient(
    sessionStorage: ref.watch(sessionStorageProvider),
  );
  ref.onDispose(client.close);
  return client;
});

final chainVerifierProvider = Provider<ChainVerifier>((ref) {
  final verifier = ChainVerifier();
  ref.onDispose(verifier.close);
  return verifier;
});

final chainAnchorStatusProvider =
    AsyncNotifierProvider<ChainAnchorController, ChainAnchorStatus>(
      ChainAnchorController.new,
    );

class ChainAnchorController extends AsyncNotifier<ChainAnchorStatus> {
  bool _requestRunning = false;

  @override
  Future<ChainAnchorStatus> build() async {
    final session = await ref.watch(sessionControllerProvider.future);
    final userId = session.userId;
    if (userId == null) {
      return const ChainAnchorStatus(ChainAnchorPhase.noBrews);
    }
    final repo = await ref.watch(chainAnchorRepositoryProvider.future);
    final anchor = await repo.latest(userId);
    if (anchor != null) {
      return ChainAnchorStatus(
        anchor.status == 'pending'
            ? ChainAnchorPhase.pending
            : ChainAnchorPhase.confirmed,
        anchor: anchor,
      );
    }
    final database = await ref.watch(databaseProvider.future);
    final brews = await database.query(
      'brews',
      columns: ['seq'],
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return ChainAnchorStatus(
      brews.isEmpty ? ChainAnchorPhase.noBrews : ChainAnchorPhase.unanchored,
    );
  }

  Future<void> requestAfterPush(String userId) => _request(userId);

  Future<void> resumePending(String userId) async {
    final repo = await ref.read(chainAnchorRepositoryProvider.future);
    if ((await repo.latest(userId))?.status == 'pending') {
      await _request(userId);
    }
  }

  Future<void> _request(String userId) async {
    if (_requestRunning || !_currentUser(userId)) return;
    _requestRunning = true;
    try {
      final repo = await ref.read(chainAnchorRepositoryProvider.future);
      final retryAfter = await repo.retryAfter(userId);
      if (retryAfter != null && retryAfter.isAfter(DateTime.now().toUtc()))
        return;
      final result = await ref.read(anchorClientProvider).requestAnchor(userId);
      if (!_currentUser(userId) ||
          (await ref.read(sessionStorageProvider).readSession())?.userId !=
              userId) {
        return;
      }
      switch (result) {
        case Confirmed():
          await repo.save(
            userId: userId,
            seq: result.seq,
            status: 'confirmed',
            headHash: result.headHash,
            userKey: result.userKey,
            txHash: result.txHash,
            explorerUrl: result.explorerUrl,
          );
          state = AsyncData(
            ChainAnchorStatus(
              ChainAnchorPhase.confirmed,
              anchor: await repo.latest(userId),
            ),
          );
        case Pending():
          await repo.save(
            userId: userId,
            seq: result.seq,
            status: 'pending',
            txHash: result.txHash,
          );
          state = AsyncData(
            ChainAnchorStatus(
              ChainAnchorPhase.pending,
              anchor: await repo.latest(userId),
            ),
          );
        case NothingToAnchor():
          state = const AsyncData(ChainAnchorStatus(ChainAnchorPhase.noBrews));
        case RateLimited():
          await repo.setRetryAfter(
            userId,
            DateTime.now().toUtc().add(result.retryAfter),
          );
        case Unauthorized():
          state = const AsyncData(
            ChainAnchorStatus(
              ChainAnchorPhase.failed,
              message: 'Sesi tidak sah. Masuk kembali.',
            ),
          );
        case Failed():
          state = AsyncData(
            ChainAnchorStatus(ChainAnchorPhase.failed, message: result.message),
          );
      }
    } catch (_) {
      if (_currentUser(userId)) {
        state = const AsyncData(
          ChainAnchorStatus(
            ChainAnchorPhase.failed,
            message: 'Pencatatan jangkar gagal. Coba lagi nanti.',
          ),
        );
      }
    } finally {
      _requestRunning = false;
    }
  }

  Future<ChainVerification> verifyNow() async {
    final userId = ref.read(sessionControllerProvider).asData?.value.userId;
    if (userId == null) return const Unreachable('Sesi tidak tersedia.');
    final repo = await ref.read(chainAnchorRepositoryProvider.future);
    final anchor = await repo.latest(userId);
    if (anchor?.userKey == null) {
      return const Unreachable(
        'Kunci jangkar belum tersedia di perangkat ini.',
      );
    }
    final verifier = ref.read(chainVerifierProvider);
    final chain = await verifier.readLatest(anchor!.userKey!);
    ChainVerification result = chain;
    if (chain is ChainHead) {
      try {
        final brewRepo = await ref.read(brewRepositoryProvider.future);
        final localHash = await brewRepo.verifiedHashAtSeq(userId, chain.seq);
        result = verifier.compareAtSeq(chain, localHash);
      } on BrewSaveException {
        result = verifier.compareAtSeq(chain, null, chainBroken: true);
      }
    }
    if (!_currentUser(userId)) return result;
    final value = switch (result) {
      Match() => 'match',
      Mismatch() => 'mismatch',
      NotFound() => 'not_found',
      Unknown() => 'unknown',
      _ => null,
    };
    if (value != null) {
      await repo.saveVerification(userId, anchor.seq, value);
      state = AsyncData(
        ChainAnchorStatus(
          ChainAnchorPhase.confirmed,
          anchor: await repo.latest(userId),
        ),
      );
    }
    return result;
  }

  bool _currentUser(String userId) =>
      ref.mounted &&
      ref.read(sessionControllerProvider).asData?.value.userId == userId;
}
