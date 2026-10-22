import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/state/session_controller.dart';
import '../beans/state/bean_providers.dart';
import '../brew/state/brew_setup_controller.dart';
import '../journal/state/journal_controller.dart';

class ProfileStats {
  const ProfileStats({
    required this.brewCount,
    required this.beanCount,
    required this.averageScore,
  });

  factory ProfileStats.fromScores({
    required List<int> scores,
    required int beanCount,
  }) {
    final average = scores.isEmpty
        ? null
        : scores.reduce((total, score) => total + score) / scores.length;
    return ProfileStats(
      brewCount: scores.length,
      beanCount: beanCount,
      averageScore: average,
    );
  }

  final int brewCount;
  final int beanCount;
  final double? averageScore;
}

/// Statistik ringkas pengguna aktif (hanya baca): seduhan aktif, biji aktif,
/// rata-rata skor rasa seduhan aktif.
final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final session = await ref.watch(sessionControllerProvider.future);
  final userId = session.userId;
  if (userId == null) throw StateError('Sesi tidak tersedia.');
  // Ikut dimuat ulang bila jurnal atau daftar biji berubah.
  ref.watch(journalBrewsProvider);
  final beans = await ref.watch(beanListProvider.future);
  final brews = await (await ref.watch(
    brewRepositoryProvider.future,
  )).findJournalBrews(userId: userId);
  return ProfileStats.fromScores(
    scores: [for (final brew in brews) brew.tasteScore],
    beanCount: beans.length,
  );
});
