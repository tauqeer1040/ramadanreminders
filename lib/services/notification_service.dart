import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:meowmin_notifications/meowmin_notifications.dart' as meow;
import 'package:shared_preferences/shared_preferences.dart';
import 'web_bridge.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static fln.FlutterLocalNotificationsPlugin? _notificationsPlugin;

  /// Is Android's native reminder chain active? Gates the fallback paths so
  /// we never double-post.
  static bool _nativeChainActive = false;

  /// Cancel every scheduled reminder (the "off" half of the toggle).
  static Future<void> cancelAll() async {
    await meow.MeowminNotifications.cancel();
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
      const channel = MethodChannel('com.taucity.meowmin/widget');
      final ok = await channel.invokeMethod<bool>('openAppSettings');
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

    // White face.webp silhouette (drawable-*/ic_notification.png) — Android
    // tint small icons to the channel color; the launcher icon renders as a
    // plain circle on most OEMs.
    final initializationSettingsAndroid =
        fln.AndroidInitializationSettings('ic_notification');

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

  /// Can we use EXACT alarms? True on <12, on 12+ true only when the user
  /// granted the "Alarms & reminders" special access. Exact mode is the
  /// most OEM-resistant local path (inexact alarms are deferred by Doze and
  /// dropped outright by aggressive OEMs like ColorOS/Realme UI).
  static Future<bool> canScheduleExact() async {
    try {
      final androidImpl = _notificationsPlugin
          ?.resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin
          >();
      return await androidImpl?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<fln.AndroidScheduleMode> _bestScheduleMode() async {
    return (await canScheduleExact())
        ? fln.AndroidScheduleMode.exactAllowWhileIdle
        : fln.AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Post a notification RIGHT NOW (no alarm involved). Isolates display
  /// problems (permission, channel, icon) from scheduling problems.
  static Future<void> showImmediate({
    required int id,
    required String title,
    required String body,
  }) async {
    if (_notificationsPlugin == null) await init();
    await _notificationsPlugin?.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: fln.NotificationDetails(
        android: await _androidDetails(),
      ),
    );
  }

  /// [NotifDiag] — debug-only proof sequence: 1 immediate + 3 alarms at
  /// +10/+20/+30s. On Android this runs through the package's native chain,
  /// proving display + AlarmManager end-to-end. If the immediate one shows
  /// but the 3 alarms don't, the OS/OEM is blocking alarms (battery
  /// optimization), not the code.
  static Future<void> runNotificationDiagnostics() async {
    if (!kDebugMode || kIsWeb) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final ok = await meow.MeowminNotifications.fireTestSequence();
      debugPrint('[NotifDiag] native test chain armed=$ok: immediate + 10/20/30s');
      return;
    }
    try {
      if (_notificationsPlugin == null) await init();
      final enabled = await checkPermissions();
      debugPrint('[NotifDiag] notificationsEnabled=$enabled');
      if (!enabled) {
        debugPrint('[NotifDiag] SKIP test sequence — POST_NOTIFICATIONS not granted');
        return;
      }
      await showImmediate(
        id: 9000,
        title: '🔔 Notif test 0/3 — immediate',
        body: 'If you see this, display works. 3 alarms follow at 10s/20s/30s.',
      );
      debugPrint('[NotifDiag] immediate shown');
      final mode = await _bestScheduleMode();
      final base = tz.TZDateTime.now(tz.local);
      for (var i = 1; i <= 3; i++) {
        final at = base.add(Duration(seconds: 10 * i));
        debugPrint('[NotifDiag] alarm $i/3 at $at mode=$mode');
        await _notificationsPlugin?.zonedSchedule(
          id: 9000 + i,
          title: '⏰ Notif test $i/3',
          body: 'Scheduled alarm fired at +${10 * i}s — alarms WORK.',
          scheduledDate: at,
          notificationDetails: fln.NotificationDetails(android: await _androidDetails()),
          androidScheduleMode: mode,
        );
      }
      debugPrint('[NotifDiag] 3 test alarms scheduled');
    } catch (e) {
      debugPrint('[NotifDiag] FAILED: $e');
    }
  }

  static Future<fln.AndroidNotificationDetails> _androidDetails() async {
    // Text-only (no images) — matches the package's native builder.
    return fln.AndroidNotificationDetails(
      'daily_reminders',
      'Gentle Reminders',
      channelDescription: 'Soft daily reminders for your spiritual journey',
      importance: fln.Importance.high,
      priority: fln.Priority.high,
    );
  }

  /// Best-effort display name for notification copy:
  /// onboarding name → Firebase displayName → email prefix → 'friend'.
  static Future<String> _resolveUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final onboarding = prefs.getString('onboarding_displayName')?.trim();
      if (onboarding != null && onboarding.isNotEmpty) return onboarding;
    } catch (_) {}
    final user = FirebaseAuth.instance.currentUser;
    final dn = user?.displayName?.trim();
    if (dn != null && dn.isNotEmpty) return dn;
    final email = user?.email?.trim();
    if (email != null && email.contains('@')) {
      final prefix = email.split('@').first.trim();
      if (prefix.isNotEmpty && !prefix.toLowerCase().contains('anonymous')) return prefix;
    }
    return 'friend';
  }

  /// Schedule both daily reminders through the package's native chain
  /// (Android): self-re-arming Kotlin receiver with inexact-allow-while-idle
  /// alarms, independent of the Flutter engine. Copy: cat-name heading from
  /// onboarding; personal name resolved from onboarding/email (pass
  /// [username] to override). Returns false when the native path is
  /// unavailable (non-Android) so callers can fall back.
  static Future<bool> scheduleNativeReminders({String? username}) async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android) return false;

    // Copy inputs: cat name from onboarding data, name resolved from
    // onboarding/email unless explicitly provided.
    String? catName;
    try {
      final prefs = await SharedPreferences.getInstance();
      catName = prefs.getString('onboarding_catName');
    } catch (_) {}
    final cat = (catName?.trim().isNotEmpty ?? false) ? catName!.trim() : 'Meowmin';
    final passed = username?.trim() ?? '';
    final name = passed.isNotEmpty ? passed : await _resolveUserName();

    // Copy: cat name (heading, both notifications) from onboarding data,
    // personalized body for the night diary reminder.
    final ok = await meow.MeowminNotifications.schedule(
      meow.MeowminReminderConfig(
        titleMorning: cat,
        bodyMorning: 'Read your insights for the day, $name',
        titleNight: cat,
        bodyNight: "It's time to write your diary, $name",
        morningHour: 8,
        morningMinute: 0,
        nightHour: 22,
        nightMinute: 0,
      ),
    );
    _nativeChainActive = ok;
    return ok;
  }

  static Future<void> cancelNativeReminders() async {
    _nativeChainActive = false;
    await meow.MeowminNotifications.cancel();
  }

  /// Debug-only: fire the stored day (morning) notification right now.
  static Future<void> showDayNotificationNow() async {
    if (!kDebugMode || kIsWeb) return;
    if (await _ensureNativeConfig()) {
      await meow.MeowminNotifications.showNow(isMorning: true);
    }
  }

  /// Debug-only: fire the stored night notification right now.
  static Future<void> showNightNotificationNow() async {
    if (!kDebugMode || kIsWeb) return;
    if (await _ensureNativeConfig()) {
      await meow.MeowminNotifications.showNow(isMorning: false);
    }
  }

  /// Make sure the native side has fresh copy before a direct-fire preview.
  static Future<bool> _ensureNativeConfig() async {
    if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) return false;
    final ok = await scheduleNativeReminders();
    return ok || _nativeChainActive;
  }

  static Future<void> scheduleDailyNotifications({String? username}) async {
    // Android: delegate entirely to the native chain (name resolved inside).
    if (await scheduleNativeReminders(username: username)) return;

    if (_notificationsPlugin == null) await init();
    await _notificationsPlugin?.cancelAll();

    final name = await _resolveUserName();
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
      body: 'Write your diary, $name',
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
      body: 'Your scratch cards are ready, $name',
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
      body: 'Time to relax and reflect, $name',
      dateTime: tz.TZDateTime(local, windDownTime.year, windDownTime.month, windDownTime.day, 22, 0),
    );
  }

  static Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime dateTime,
  }) async {
    // Exact when the OS allows (most OEMs deliver exact alarms reliably);
    // inexact fallback keeps Play policy compliance when the special
    // access isn't granted (a minute's drift is fine for daily reminders).
    final mode = await _bestScheduleMode();

    await _notificationsPlugin?.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: dateTime,
      notificationDetails: fln.NotificationDetails(android: await _androidDetails()),
      androidScheduleMode: mode,
      matchDateTimeComponents: fln.DateTimeComponents.time,
    );
  }
}
