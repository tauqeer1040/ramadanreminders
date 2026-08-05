import 'dart:js_interop';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:web/web.dart' as web;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(settings: initializationSettings);
  }
  static Future<bool> requestPermissions() async {
    if (kIsWeb) {
      final jsResult = await web.Notification.requestPermission().toDart;
      return jsResult == 'granted';
    }
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    final bool? granted = await androidImplementation
        ?.requestNotificationsPermission();
    return granted ?? false;
  }

  static Future<bool> checkPermissions() async {
    if (kIsWeb) {
      return web.Notification.permission == 'granted';
    }
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

    final bool? granted = await androidImplementation
        ?.areNotificationsEnabled();
    return granted ?? false;
  }

  static Future<void> scheduleDailyNotifications({String username = 'you'}) async {
    await _notificationsPlugin.cancelAll();

    final now = DateTime.now();
    final local = tz.local;

    // Morning — 9:00 AM — diary prompt
    var morningTime = DateTime(now.year, now.month, now.day, 9, 0);
    if (morningTime.isBefore(now)) {
      morningTime = morningTime.add(const Duration(days: 1));
    }
    await _scheduleAt(
      id: 1,
      title: '📝 Time to Reflect',
      body: 'Write your diary $username',
      dateTime: tz.TZDateTime(local, morningTime.year, morningTime.month, morningTime.day, 9, 0),
    );

    // Night — 9:00 PM — scratch cards reminder
    var nightTime = DateTime(now.year, now.month, now.day, 21, 0);
    if (nightTime.isBefore(now)) {
      nightTime = nightTime.add(const Duration(days: 1));
    }
    await _scheduleAt(
      id: 2,
      title: '🎁 Scratch Cards Ready',
      body: 'your scratch cards are ready $username',
      dateTime: tz.TZDateTime(local, nightTime.year, nightTime.month, nightTime.day, 21, 0),
    );

    // Night — 10:00 PM — wind-down reminder
    var windDownTime = DateTime(now.year, now.month, now.day, 22, 0);
    if (windDownTime.isBefore(now)) {
      windDownTime = windDownTime.add(const Duration(days: 1));
    }
    await _scheduleAt(
      id: 3,
      title: '🌙 Wind Down',
      body: 'Time to relax and reflect $username',
      dateTime: tz.TZDateTime(local, windDownTime.year, windDownTime.month, windDownTime.day, 22, 0),
    );
  }

  static Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime dateTime,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'daily_reminders',
          'Gentle Reminders',
          channelDescription: 'Soft daily reminders for your spiritual journey',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          largeIcon: const DrawableResourceAndroidBitmap('mascot_notification'),
          styleInformation: const BigPictureStyleInformation(
            DrawableResourceAndroidBitmap('mascot_notification'),
            hideExpandedLargeIcon: true,
          ),
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: dateTime,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
