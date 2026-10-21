import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import 'notification_schedule.dart';

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _initialization;
  void Function(String)? onTap;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'tetes_reminders',
      'Pengingat Tetes',
      channelDescription: 'Pengingat event, seduh, dan stok biji',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    timezone_data.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null) onTap?.call(payload);
      },
    );
  }

  Future<String?> launchPayload() async {
    await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse?.payload
        : null;
  }

  Future<bool> permissionGranted() async {
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ??
          true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.checkPermissions()
              .then((value) => value?.isEnabled ?? false) ??
          false;
    }
    return true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return true;
  }

  Future<bool> canScheduleExact() async {
    await initialize();
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.canScheduleExactNotifications() ??
        false;
  }

  Future<void> schedule(NotificationRequest request) async {
    await initialize();
    if (!await permissionGranted()) return;
    await _plugin.zonedSchedule(
      id: request.id,
      title: request.title,
      body: request.body,
      scheduledDate: tz.TZDateTime.from(request.atUtc, tz.UTC),
      notificationDetails: _details,
      payload: request.payload,
      androidScheduleMode: await canScheduleExact()
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> show(NotificationRequest request) async {
    await initialize();
    if (!await permissionGranted()) return;
    await _plugin.show(
      id: request.id,
      title: request.title,
      body: request.body,
      notificationDetails: _details,
      payload: request.payload,
    );
  }

  Future<void> cancel(int id) async {
    await initialize();
    await _plugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }
}
