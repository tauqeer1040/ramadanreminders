import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel;
import 'web_bridge.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static fln.FlutterLocalNotificationsPlugin? _notificationsPlugin;
  static const _settingsChannel =
      MethodChannel('com.taucity.meowmin/widget');

  /// Cancel every scheduled reminder (the "off" half of the toggle).
  static Future<void> cancelAll() async {
    try {
      await _notificationsPlugin?.cancelAll();
    } catch (_) {}
  }

  /// Open the app's system settings page (for users who denied permission
  /// twice — Android stops showing the dialog and settings is the only path).
  /// Returns true when the settings screen was launched.
  static Future<bool> openAppSettings() async {
    if (kIsWeb) return false;
    try {
      if (defaultTargetPlatform != TargetPlatform.android) return false;
      final ok = await _settingsChannel.invokeMethod<bool>('openAppSettings');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> init() async {
    _notificationsPlugin ??= fln.FlutterLocalNotificationsPlugin();
    tz.initializeTimeZones();
    // Device-local timezone — without this tz.local stays UTC and daily
    // reminders fire at the wrong wall-clock hour.
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      // UTC fallback; times still scheduled, just possibly offset.
    }

    final initializationSettingsAndroid =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');

    final initializationSettingsDarwin =
        fln.DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );

    final initializationSettings =
        fln.InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin!.initialize(settings: initializationSettings);
  }
  // Web Notifications are unavailable on iOS Safari (and most Safari installs)
  // — `window.Notification` is undefined there. Feature-detect the runtime
  // global and treat as not granted rather than throwing a JS TypeError.
  static bool get _webNotificationsSupported {
    try {
      return globalContext.has('Notification');
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPermissions() async {
    if (kIsWeb) {
      if (!_webNotificationsSupported) return false;
      try {
        final result = await Notification.requestPermission();
        return result?.toString() == 'granted';
      } catch (_) {
        return false;
      }
    }
    // Self-ensuring init: callers (e.g. splash) may race init(). A null
    // plugin would silently return false and burn one-shot flags.
    if (_notificationsPlugin == null) await init();
    // v20+: generic-only API — passing the type as a positional argument
    // throws NoSuchMethodError at runtime (dynamic call, invisible to analyze).
    final androidImplementation = _notificationsPlugin
        ?.resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin
        >();

    final bool? granted = await androidImplementation
        ?.requestNotificationsPermission();
    return granted ?? false;
  }

  static Future<bool> checkPermissions() async {
    if (kIsWeb) {
      if (!_webNotificationsSupported) return false;
      try {
        return Notification.permission == 'granted';
      } catch (_) {
        return false;
      }
    }
    if (_notificationsPlugin == null) await init();
    final androidImplementation = _notificationsPlugin
        ?.resolvePlatformSpecificImplementation<
          fln.AndroidFlutterLocalNotificationsPlugin
        >();

    final bool? granted = await androidImplementation
        ?.areNotificationsEnabled();
    return granted ?? false;
  }

  static Future<void> scheduleDailyNotifications({String username = 'you'}) async {
    if (_notificationsPlugin == null) await init();
    await _notificationsPlugin?.cancelAll();

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
    final androidDetails =
        fln.AndroidNotificationDetails(
          'daily_reminders',
          'Gentle Reminders',
          channelDescription: 'Soft daily reminders for your spiritual journey',
          importance: fln.Importance.defaultImportance,
          priority: fln.Priority.defaultPriority,
          largeIcon: fln.DrawableResourceAndroidBitmap('mascot_notification'),
          styleInformation: fln.BigPictureStyleInformation(
            fln.DrawableResourceAndroidBitmap('mascot_notification'),
            hideExpandedLargeIcon: true,
          ),
        );

    final notificationDetails = fln.NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin?.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: dateTime,
      notificationDetails: notificationDetails,
      // Pure inexact by design (a minute's drift is fine for daily
      // reminders): no exact-alarm permission, no policy declaration,
      // no locked system toggle. See Play review notes.
      androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: fln.DateTimeComponents.time,
    );
  }
}
