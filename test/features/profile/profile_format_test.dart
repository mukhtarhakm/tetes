import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/features/profile/profile_format.dart';
import 'package:tetes/features/profile/profile_stats.dart';

void main() {
  test('tanggal bergabung memakai bulan bahasa Indonesia', () {
    expect(formatJoinedDate(DateTime(2026, 10, 18)), '18 Okt 2026');
    expect(formatJoinedDate(DateTime(2026, 5, 3)), '3 Mei 2026');
  });

  test('jam 24 jam dengan titik', () {
    expect(formatClock(8, 0), '08.00');
    expect(formatClock(20, 5), '20.05');
  });

  test('waktu relatif: hari ini, kemarin, atau tanggal', () {
    final now = DateTime(2026, 10, 23, 9, 0);
    expect(
      formatRelativeDateTime(DateTime(2026, 10, 23, 7, 31), now),
      'hari ini, 07.31',
    );
    expect(
      formatRelativeDateTime(DateTime(2026, 10, 22, 20, 31), now),
      'kemarin, 20.31',
    );
    expect(
      formatRelativeDateTime(DateTime(2026, 10, 18, 6, 0), now),
      '18 Okt, 06.00',
    );
  });

  test('rata-rata skor memakai koma atau tanda hubung', () {
    expect(formatAverageScore(null), '-');
    expect(formatAverageScore(4.1), '4,1');
    expect(formatAverageScore(3), '3,0');
  });

  test('ringkasan hari pengingat', () {
    expect(describeReminderDays({1, 2, 3, 4, 5, 6, 7}), 'Setiap hari');
    expect(describeReminderDays({1, 2, 3, 4, 5}), 'Senin sampai Jumat');
    expect(describeReminderDays({6, 7}), 'Akhir pekan');
    expect(describeReminderDays({1, 3, 5}), 'Sen, Rab, Jum');
    expect(describeReminderDays({}), 'Belum ada hari dipilih');
  });

  test('statistik profil dari daftar skor', () {
    final empty = ProfileStats.fromScores(scores: const [], beanCount: 2);
    expect(empty.brewCount, 0);
    expect(empty.averageScore, isNull);
    expect(empty.beanCount, 2);

    final stats = ProfileStats.fromScores(scores: const [4, 5, 3], beanCount: 1);
    expect(stats.brewCount, 3);
    expect(stats.averageScore, closeTo(4.0, 1e-9));
  });
}
