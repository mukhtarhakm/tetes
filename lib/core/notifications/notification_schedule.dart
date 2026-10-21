import '../utils/event_time.dart';

// Rentang ID: event 10..999999999, seduh 1000000000..1000000013,
// stok 1100000000..2099999999; uji 1099999999.
// Penghitung event dan stok disimpan di settings.
const dailyNotificationBase = 1000000000;
const stockNotificationBase = 1100000000;

class NotificationEvent {
  const NotificationEvent({
    required this.id,
    required this.userId,
    required this.name,
    required this.startUtc,
    required this.sourceZone,
    required this.reminderMinutes,
    required this.baseId,
    this.deleted = false,
  });
  final String id;
  final String userId;
  final String name;
  final DateTime startUtc;
  final String sourceZone;
  final List<int> reminderMinutes;
  final int baseId;
  final bool deleted;
}

class BrewReminder {
  const BrewReminder({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.days,
  });
  final bool enabled;
  final int hour;
  final int minute;
  final Set<int> days;
}

class StockAlert {
  const StockAlert({
    required this.userId,
    required this.id,
    required this.beanName,
    required this.beforeG,
    required this.afterG,
    required this.thresholdG,
  });
  final String userId;
  final int id;
  final String beanName;
  final double beforeG;
  final double afterG;
  final double thresholdG;
}

class NotificationRequest {
  const NotificationRequest({
    required this.id,
    required this.atUtc,
    required this.title,
    required this.body,
    required this.payload,
    this.immediate = false,
  });
  final int id;
  final DateTime atUtc;
  final String title;
  final String body;
  final String payload;
  final bool immediate;
}

List<NotificationRequest> planNotifications({
  required String userId,
  required List<NotificationEvent> events,
  required BrewReminder brew,
  required List<StockAlert> stocks,
  required DateTime now,
}) {
  final result = <NotificationRequest>[];
  final nowUtc = now.toUtc();
  for (final event in events) {
    if (event.userId != userId || event.deleted) continue;
    for (var index = 0; index < event.reminderMinutes.length; index++) {
      final minutes = event.reminderMinutes[index];
      final at = event.startUtc.toUtc().subtract(Duration(minutes: minutes));
      if (!at.isAfter(nowUtc)) continue;
      final until = minutes == 1440
          ? '1 hari'
          : minutes >= 60
          ? '${minutes ~/ 60} jam'
          : '$minutes menit';
      result.add(
        NotificationRequest(
          id: event.baseId * 10 + index,
          atUtc: at,
          title: 'Pengingat event',
          body:
              '${event.name} dimulai dalam $until. WIB: '
              '${EventTime.localText(event.startUtc, 'Asia/Jakarta')}; '
              '${EventTime.zones.entries.firstWhere((e) => e.value == event.sourceZone).key}: '
              '${EventTime.localText(event.startUtc, event.sourceZone)}',
          payload: 'event:${event.id}',
        ),
      );
    }
  }
  if (brew.enabled && brew.days.isNotEmpty) {
    final localNow = now.toLocal();
    for (var offset = 0; offset < 14; offset++) {
      final day = DateTime(
        localNow.year,
        localNow.month,
        localNow.day + offset,
      );
      if (!brew.days.contains(day.weekday)) continue;
      final at = DateTime(day.year, day.month, day.day, brew.hour, brew.minute);
      if (!at.toUtc().isAfter(nowUtc)) continue;
      result.add(
        NotificationRequest(
          id: dailyNotificationBase + offset,
          atUtc: at.toUtc(),
          title: 'Waktunya seduh',
          body: 'Luangkan waktu untuk menyeduh kopi hari ini.',
          payload: 'brew',
        ),
      );
    }
  }
  for (final stock in stocks) {
    if (stock.userId != userId ||
        stock.beforeG < stock.thresholdG ||
        stock.afterG >= stock.thresholdG) {
      continue;
    }
    result.add(
      NotificationRequest(
        id: stockNotificationBase + stock.id,
        atUtc: nowUtc,
        title: 'Stok menipis',
        body:
            'Stok ${stock.beanName} tinggal ${stock.afterG.toStringAsFixed(1)} g',
        payload: 'stock',
        immediate: true,
      ),
    );
  }
  assert(result.map((request) => request.id).toSet().length == result.length);
  return result;
}
