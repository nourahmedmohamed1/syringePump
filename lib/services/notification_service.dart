// lib/services/notification_service.dart
import 'dart:ui' show Color;
import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef OnNotificationTapped = void Function(int id);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  OnNotificationTapped? onNotificationTapped;

  Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(android: android, iOS: ios);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final id = response.id ?? -1;
    onNotificationTapped?.call(id);
    if (id >= 0) {
      _plugin.cancel(id);
    }
  }

  Future<void> showAlarm({
    required int id,
    required String title,
    required String body,
    bool isCritical = false,
  }) async {
    await init();
    final androidDetails = AndroidNotificationDetails(
      'syringe_pump_alarms',
      'Syringe Pump Alarms',
      channelDescription: 'Critical alerts from the syringe pump monitor',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      playSound: false,
      enableVibration: true,
      vibrationPattern: isCritical
          ? Int64List.fromList([0, 300, 200, 300, 200, 300])
          : Int64List.fromList([0, 200, 100, 200]),
      color: isCritical
          ? const Color(0xFFFF1744)
          : const Color(0xFFFFAB00),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'stop_alarm_$id',
          '✅ DISMISS',
          cancelNotification: true,
          showsUserInterface: false,
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, title, body, details);
  }

  Future<List<ActiveNotification>> getActiveNotifications() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.getActiveNotifications();
    }
    return [];
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
