import 'package:flutter_test/flutter_test.dart';
import 'package:tetes/core/notifications/notification_coordinator.dart';
import 'package:tetes/core/notifications/notification_schedule.dart';
import 'package:tetes/core/notifications/notification_service.dart';

class FakeNotificationService extends NotificationService {
  int cancelAllCount = 0;

  @override
  Future<void> initialize() async {}
  @override
  Future<String?> launchPayload() async => null;
  @override
  Future<bool> permissionGranted() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> canScheduleExact() async => true;
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
  }

  @override
  Future<void> schedule(NotificationRequest request) async {}
  @override
  Future<void> show(NotificationRequest request) async {}
}

class FakeNotificationCoordinator extends Fake
    implements NotificationCoordinator {
  @override
  Future<void> refreshAll(String userId) async {}

  @override
  Future<NotificationSettings> loadSettings(String userId) async =>
      const NotificationSettings(
        enabled: false,
        hour: 8,
        minute: 0,
        days: {1, 2, 3, 4, 5, 6, 7},
        stockThresholdG: 15,
      );
}
