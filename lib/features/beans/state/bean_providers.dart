import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database_provider.dart';
import '../../../data/remote/fx_client.dart';
import '../../../data/repositories/bean_repo.dart';
import '../../auth/state/session_controller.dart';
import '../../brew/state/brew_setup_controller.dart';
import '../../journal/journal_model.dart';
import '../bean_model.dart';
import '../fx_quote_service.dart';

final beanRepositoryProvider = FutureProvider<BeanRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return BeanRepository(database);
});

final fxRateSourceProvider = Provider<FxRateSource>((ref) {
  final client = FxClient();
  ref.onDispose(client.close);
  return client;
});

final fxNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final fxQuoteServiceProvider = FutureProvider<FxQuoteService>((ref) async {
  final userId = await _activeUserId(ref);
  final repository = await ref.watch(beanRepositoryProvider.future);
  return FxQuoteService(
    source: ref.watch(fxRateSourceProvider),
    cache: repository,
    userId: userId,
    now: ref.watch(fxNowProvider),
  );
});

final beanListProvider = AsyncNotifierProvider<BeanListController, List<Bean>>(
  BeanListController.new,
);

final archivedBeanListProvider = FutureProvider<List<Bean>>((ref) async {
  final userId = await _activeUserId(ref);
  final repository = await ref.watch(beanRepositoryProvider.future);
  return repository.findArchived(userId: userId);
});

final beanDetailProvider = FutureProvider.family<Bean?, String>((
  ref,
  id,
) async {
  final userId = await _activeUserId(ref);
  final repository = await ref.watch(beanRepositoryProvider.future);
  return repository.findById(userId: userId, id: id);
});

final beanActiveBrewsProvider =
    FutureProvider.family<List<BrewJournalItem>, String>((ref, beanId) async {
      final userId = await _activeUserId(ref);
      final repository = await ref.watch(brewRepositoryProvider.future);
      return repository.findBrewsForBean(
        userId: userId,
        beanId: beanId,
        activeOnly: true,
        chronological: true,
      );
    });

final beanHistoryBrewsProvider =
    FutureProvider.family<List<BrewJournalItem>, String>((ref, beanId) async {
      final userId = await _activeUserId(ref);
      final repository = await ref.watch(brewRepositoryProvider.future);
      return repository.findBrewsForBean(
        userId: userId,
        beanId: beanId,
        activeOnly: false,
        chronological: false,
      );
    });

final beanMutationProvider =
    AsyncNotifierProvider<BeanMutationController, void>(
      BeanMutationController.new,
    );

class BeanListController extends AsyncNotifier<List<Bean>> {
  @override
  Future<List<Bean>> build() async {
    final userId = await _activeUserId(ref);
    final repository = await ref.watch(beanRepositoryProvider.future);
    return repository.listActive(userId);
  }

  void refresh() {
    ref.invalidateSelf();
  }
}

class BeanMutationController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> save({required BeanDraft draft, String? beanId}) async {
    if (state.isLoading) {
      return null;
    }
    state = const AsyncLoading();
    try {
      final userId = await _activeUserId(ref);
      final repository = await ref.read(beanRepositoryProvider.future);
      final savedId = beanId == null
          ? await repository.create(userId: userId, draft: draft)
          : await _update(
              repository,
              userId: userId,
              beanId: beanId,
              draft: draft,
            );
      state = const AsyncData(null);
      ref.invalidate(beanListProvider);
      ref.invalidate(archivedBeanListProvider);
      if (beanId != null) {
        ref.invalidate(beanDetailProvider(beanId));
      }
      return savedId;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    }
  }

  Future<bool> archive(String beanId) async {
    if (state.isLoading) {
      return false;
    }
    state = const AsyncLoading();
    try {
      final userId = await _activeUserId(ref);
      final repository = await ref.read(beanRepositoryProvider.future);
      await repository.archive(userId: userId, id: beanId);
      state = const AsyncData(null);
      ref.invalidate(beanListProvider);
      ref.invalidate(archivedBeanListProvider);
      ref.invalidate(beanDetailProvider(beanId));
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> restore(String beanId) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      final userId = await _activeUserId(ref);
      final repository = await ref.read(beanRepositoryProvider.future);
      await repository.restore(userId: userId, id: beanId);
      state = const AsyncData(null);
      ref.invalidate(beanListProvider);
      ref.invalidate(archivedBeanListProvider);
      ref.invalidate(beanDetailProvider(beanId));
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<String> _update(
    BeanRepository repository, {
    required String userId,
    required String beanId,
    required BeanDraft draft,
  }) async {
    await repository.update(userId: userId, id: beanId, draft: draft);
    return beanId;
  }
}

Future<String> _activeUserId(Ref ref) async {
  final session = await ref.watch(sessionControllerProvider.future);
  final userId = session.userId;
  if (session.status != SessionStatus.authenticated || userId == null) {
    throw StateError('Session pengguna tidak tersedia.');
  }
  return userId;
}
