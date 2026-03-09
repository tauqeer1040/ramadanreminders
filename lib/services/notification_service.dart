import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:adhan/adhan.dart';
import 'prayer_time_service.dart';
import 'dart:math';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static final List<String> _suhoorMessages = [
    "🌅 Before Suhoor: set today's intention.",
    "🌅 Time to wake up! A little food, a lot of barakah.",
    "🌅 Don't miss Suhoor, there is blessing in it.",
  ];

  static final List<String> _maghribMessages = [
    "🌇 Maghrib is near. One line of gratitude?",
    "🌇 Maghrib is near. Make Dikhr?",
    "🌇 The fast is ending soon. Make dua",
    "🌇 Prepare your heart for God's bounty, Iftar.",
  ];

  static final List<String> _nightMessages = [
    "🌙 End the day with one du'a.",
    "🌙 Sleep with a clean heart.",
    "🌙 Before bed: Have you recited Ayatul Kursi?",
    "🌙 An Aayah of the Quran before bed?",
  ];

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
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    final bool? granted = await androidImplementation
        ?.areNotificationsEnabled();
    return granted ?? false;
  }

  static Future<void> scheduleDailyNotifications() async {
    await _notificationsPlugin.cancelAll();

    final prayerTimes = await PrayerTimeService.getPrayerTimes();
    if (prayerTimes != null) {
      // Schedule Suhoor (30 mins before Fajr)
      final suhoorTime = prayerTimes.fajr.subtract(const Duration(minutes: 30));
      if (suhoorTime.isAfter(DateTime.now())) {
        _scheduleAt(
          id: 1,
          title: "Suhoor Reminder",
          body: _getRandomMessage(_suhoorMessages),
          time: suhoorTime,
        );
      }

      // Schedule Iftar (15 mins before Maghrib)
      final iftarTime = prayerTimes.maghrib.subtract(
        const Duration(minutes: 15),
      );
      if (iftarTime.isAfter(DateTime.now())) {
        _scheduleAt(
          id: 2,
          title: "Iftar Approaching",
          body: _getRandomMessage(_maghribMessages),
          time: iftarTime,
        );
      }
    }

    // Schedule Night time (10:00 PM)
    final now = DateTime.now();
    var nightTime = DateTime(now.year, now.month, now.day, 22, 0);
    if (nightTime.isBefore(now)) {
      nightTime = nightTime.add(const Duration(days: 1));
    }
    _scheduleAt(
      id: 3,
      title: "Night Reflection",
      body: _getRandomMessage(_nightMessages),
      time: nightTime,
    );
  }

  static Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime time,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'ramadan_reminders',
          'Gentle Reminders',
          channelDescription: 'Soft daily reminders to enrich your Ramadan',
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
      scheduledDate: tz.TZDateTime.from(time, tz.local),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> showInstantNotification(String title, String body) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'ramadan_reminders_test',
          'Test Reminders',
          channelDescription: 'Testing channel',
          importance: Importance.max,
          priority: Priority.high,
          largeIcon: const DrawableResourceAndroidBitmap('mascot_notification'),
          styleInformation: const BigPictureStyleInformation(
            DrawableResourceAndroidBitmap('mascot_notification'),
            hideExpandedLargeIcon: true,
          ),
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );
    await _notificationsPlugin.show(
      id: 88,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }

  static String _getRandomMessage(List<String> messages) {
    final random = Random();
    return messages[random.nextInt(messages.length)];
  }
}
