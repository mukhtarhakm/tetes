import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/core/notifications/notification_schedule.dart';

void main() {
  final now = DateTime(2026, 10, 21, 12);
  const disabled = BrewReminder(enabled: false, hour: 8, minute: 0, days: {});

  test(
    'tiga pengingat, lampau dilewati, user lain dan event hapus diabaikan',
    () {
      final start = now.toUtc().add(const Duration(days: 3));
      NotificationEvent event(
        String id,
        String owner, {
        bool deleted = false,
      }) => NotificationEvent(
        id: id,
        userId: owner,
        name: 'Cupping',
        startUtc: start,
        sourceZone: 'Asia/Jakarta',
        reminderMinutes: const [1440, 180, 30],
        baseId: 15,
        deleted: deleted,
      );
      final planned = planNotifications(
        userId: 'u1',
        events: [
          event('a', 'u1'),
          event('b', 'u2'),
          event('c', 'u1', deleted: true),
        ],
        brew: disabled,
        stocks: const [],
        now: now,
      );
      expect(planned.map((e) => e.id), [150, 151, 152]);
      expect(planned.every((e) => e.body.contains('WIB:')), isTrue);
      final past = planNotifications(
        userId: 'u1',
        events: [
          NotificationEvent(
            id: 'a',
            userId: 'u1',
            name: 'Cupping',
            startUtc: now.toUtc().add(const Duration(hours: 2)),
            sourceZone: 'Asia/Jakarta',
            reminderMinutes: const [1440, 180, 30],
            baseId: 15,
          ),
        ],
        brew: disabled,
        stocks: const [],
        now: now,
      );
      expect(past.map((e) => e.id), [152]);
    },
  );

  test('pengingat seduh 14 hari mengikuti jam lokal dan hari terpilih', () {
    final planned = planNotifications(
      userId: 'u1',
      events: const [],
      brew: const BrewReminder(
        enabled: true,
        hour: 8,
        minute: 30,
        days: {1, 3},
      ),
      stocks: const [],
      now: now,
    );
    expect(planned.length, 3);
    expect(
      planned.every(
        (e) =>
            e.atUtc.toLocal().hour == 8 &&
            e.atUtc.toLocal().minute == 30 &&
            {1, 3}.contains(e.atUtc.toLocal().weekday),
      ),
      isTrue,
    );
    expect(planned.map((e) => e.id).toSet().length, planned.length);
  });

  test('stok menipis hanya saat melintasi ambang dan id terpisah', () {
    final planned = planNotifications(
      userId: 'u1',
      events: const [],
      brew: disabled,
      stocks: const [
        StockAlert(
          userId: 'u1',
          id: 0,
          beanName: 'A',
          beforeG: 20,
          afterG: 10,
          thresholdG: 15,
        ),
        StockAlert(
          userId: 'u1',
          id: 1,
          beanName: 'B',
          beforeG: 12,
          afterG: 5,
          thresholdG: 15,
        ),
        StockAlert(
          userId: 'u2',
          id: 2,
          beanName: 'C',
          beforeG: 20,
          afterG: 10,
          thresholdG: 15,
        ),
      ],
      now: now,
    );
    expect(planned.map((e) => e.id), [stockNotificationBase]);
    expect(planned.single.immediate, isTrue);
    expect(planned.single.payload, 'stock');
  });
}
