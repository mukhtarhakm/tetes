import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/db/database_provider.dart';
import '../../data/repositories/event_repo.dart';
import 'notification_schedule.dart';
import 'notification_service.dart';

final notificationCoordinatorProvider = FutureProvider<NotificationCoordinator>(
  (ref) async => NotificationCoordinator(
    await ref.watch(databaseProvider.future),
    ref.watch(notificationServiceProvider),
  ),
);

class NotificationSettings {
  const NotificationSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.days,
    required this.stockThresholdG,
  });
  final bool enabled;
  final int hour;
  final int minute;
  final Set<int> days;
  final double stockThresholdG;

  BrewReminder get brew =>
      BrewReminder(enabled: enabled, hour: hour, minute: minute, days: days);
}

class NotificationCoordinator {
  const NotificationCoordinator(this._database, this._service);
  final Database _database;
  final NotificationService _service;

  Future<NotificationSettings> loadSettings(String userId) async {
    final rows = await _database.query(
      'settings',
      where: 'user_id = ? AND key IN (?, ?, ?, ?)',
      whereArgs: [
        userId,
        'brew_reminder_enabled',
        'brew_reminder_time',
        'brew_reminder_days',
        'low_stock_threshold_g',
      ],
    );
    final values = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    final time = (values['brew_reminder_time'] ?? '08:00').split(':');
    final days = (values['brew_reminder_days'] ?? '1,2,3,4,5,6,7')
        .split(',')
        .map(int.tryParse)
        .whereType<int>()
        .where((day) => day >= 1 && day <= 7)
        .toSet();
    return NotificationSettings(
      enabled: values['brew_reminder_enabled'] == '1',
      hour: int.tryParse(time.first) ?? 8,
      minute: time.length > 1 ? int.tryParse(time[1]) ?? 0 : 0,
      days: days,
      stockThresholdG:
          double.tryParse(values['low_stock_threshold_g'] ?? '') ?? 15,
    );
  }

  Future<void> saveSettings(
    String userId,
    NotificationSettings settings,
  ) async {
    if (settings.enabled && settings.days.isEmpty) {
      throw ArgumentError('Pilih minimal satu hari pengingat.');
    }
    if (settings.hour < 0 ||
        settings.hour > 23 ||
        settings.minute < 0 ||
        settings.minute > 59 ||
        settings.stockThresholdG < 0 ||
        settings.stockThresholdG > 500 ||
        !settings.stockThresholdG.isFinite) {
      throw ArgumentError('Periksa jam dan ambang stok.');
    }
    final days = settings.days.toList()..sort();
    await _database.transaction((txn) async {
      for (final entry in {
        'brew_reminder_enabled': settings.enabled ? '1' : '0',
        'brew_reminder_time':
            '${settings.hour.toString().padLeft(2, '0')}:${settings.minute.toString().padLeft(2, '0')}',
        'brew_reminder_days': days.join(','),
        'low_stock_threshold_g': settings.stockThresholdG.toString(),
      }.entries) {
        await txn.insert('settings', {
          'user_id': userId,
          'key': entry.key,
          'value': entry.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    await rescheduleDaily(userId);
  }

  Future<List<NotificationEvent>> _events(String userId) async {
    final repository = EventRepository(_database);
    await repository.ensureNotificationBaseIds(userId);
    final events = await repository.listActive(userId);
    return events
        .where((event) => event.notifBaseId != null)
        .map(
          (event) => NotificationEvent(
            id: event.id,
            userId: userId,
            name: event.name,
            startUtc: event.startUtc,
            sourceZone: event.sourceZone,
            reminderMinutes: event.reminderMinutes
                .split(',')
                .map(int.parse)
                .toList(),
            baseId: event.notifBaseId!,
          ),
        )
        .toList();
  }

  Future<void> refreshAll(String userId) async {
    final events = await _events(userId);
    final settings = await loadSettings(userId);
    await _service.cancelAll();
    if (!await _service.permissionGranted()) return;
    final requests = planNotifications(
      userId: userId,
      events: events,
      brew: settings.brew,
      stocks: const [],
      now: DateTime.now(),
    );
    for (final request in requests) {
      await _service.schedule(request);
    }
  }

  Future<void> rescheduleEvent(String userId, int? oldBaseId) async {
    if (oldBaseId != null) {
      for (var index = 0; index < 3; index++) {
        await _service.cancel(oldBaseId * 10 + index);
      }
    }
    if (!await _service.permissionGranted()) return;
    final events = await _events(userId);
    for (final request in planNotifications(
      userId: userId,
      events: events,
      brew: const BrewReminder(enabled: false, hour: 0, minute: 0, days: {}),
      stocks: const [],
      now: DateTime.now(),
    )) {
      await _service.schedule(request);
    }
  }

  Future<void> rescheduleDaily(String userId) async {
    for (var index = 0; index < 14; index++) {
      await _service.cancel(dailyNotificationBase + index);
    }
    if (!await _service.permissionGranted()) return;
    final settings = await loadSettings(userId);
    for (final request in planNotifications(
      userId: userId,
      events: const [],
      brew: settings.brew,
      stocks: const [],
      now: DateTime.now(),
    )) {
      await _service.schedule(request);
    }
  }

  Future<void> showStockCrossing({
    required String userId,
    required String beanName,
    required double beforeG,
    required double afterG,
  }) async {
    final settings = await loadSettings(userId);
    if (beforeG < settings.stockThresholdG ||
        afterG >= settings.stockThresholdG ||
        !await _service.permissionGranted()) {
      return;
    }
    final id = await _nextStockId(userId);
    final requests = planNotifications(
      userId: userId,
      events: const [],
      brew: const BrewReminder(enabled: false, hour: 0, minute: 0, days: {}),
      stocks: [
        StockAlert(
          userId: userId,
          id: id,
          beanName: beanName,
          beforeG: beforeG,
          afterG: afterG,
          thresholdG: settings.stockThresholdG,
        ),
      ],
      now: DateTime.now(),
    );
    for (final request in requests) {
      await _service.show(request);
    }
  }

  Future<int> _nextStockId(String userId) async =>
      _database.transaction((txn) async {
        final rows = await txn.query(
          'settings',
          columns: ['value'],
          where: 'user_id = ? AND key = ?',
          whereArgs: [userId, 'next_stock_notif_id'],
          limit: 1,
        );
        final next = rows.isEmpty
            ? 0
            : int.tryParse(rows.single['value'] as String) ?? 0;
        if (next > 999999999) {
          throw StateError('Batas ID notifikasi stok tercapai.');
        }
        await txn.insert('settings', {
          'user_id': userId,
          'key': 'next_stock_notif_id',
          'value': '${next + 1}',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        return next;
      });

  Future<void> showTest() async {
    await _service.show(
      NotificationRequest(
        id: stockNotificationBase - 1,
        atUtc: DateTime.now().toUtc(),
        title: 'Notifikasi uji Tetes',
        body: 'Notifikasi berhasil diaktifkan.',
        payload: 'brew',
        immediate: true,
      ),
    );
  }
}
