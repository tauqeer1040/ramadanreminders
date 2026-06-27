import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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

    final now = DateTime.now();

    // Morning — 9:00 AM
    var morningTime = DateTime(now.year, now.month, now.day, 9, 0);
    if (morningTime.isBefore(now)) {
      morningTime = morningTime.add(const Duration(days: 1));
    }
    _scheduleAt(
      id: 1,
      title: '🌅 Good Morning!',
      body: "Your scratch cards are ready — come scratch and reveal today's rewards!",
      time: morningTime,
    );

    // Night — 10:00 PM
    var nightTime = DateTime(now.year, now.month, now.day, 22, 0);
    if (nightTime.isBefore(now)) {
      nightTime = nightTime.add(const Duration(days: 1));
    }
    _scheduleAt(
      id: 2,
      title: '📝 Time to Reflect',
      body: "Write your diary — capture today's thoughts before you sleep.",
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
      scheduledDate: tz.TZDateTime.from(time, tz.local),
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
