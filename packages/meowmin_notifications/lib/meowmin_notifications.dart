import 'package:flutter/services.dart';

/// Configuration for the two daily reminders.
///
/// Titles/bodies are stored natively, so the self-re-arming receiver can
/// render notifications with the Flutter engine dead.
class MeowminReminderConfig {
  const MeowminReminderConfig({
    this.titleMorning,
    this.bodyMorning,
    this.titleNight,
    this.bodyNight,
    this.morningHour = 8,
    this.morningMinute = 0,
    this.nightHour = 22,
    this.nightMinute = 0,
  });

  /// Notification title/body for the morning reminder (default 8:00).
  final String? titleMorning;
  final String? bodyMorning;

  /// Notification title/body for the night reminder (default 22:00).
  final String? titleNight;
  final String? bodyNight;

  final int morningHour;
  final int morningMinute;
  final int nightHour;
  final int nightMinute;

  Map<String, Object> toMap() => {
        'titleMorning': titleMorning ?? 'Reminder',
        'bodyMorning': bodyMorning ?? '',
        'titleNight': titleNight ?? 'Reminder',
        'bodyNight': bodyNight ?? '',
        'morningHour': morningHour,
        'morningMinute': morningMinute,
        'nightHour': nightHour,
        'nightMinute': nightMinute,
      };
}

/// Native daily-reminder chain for Android (the "Monito pattern"):
///
///  1. Dart calls [schedule] once while the app is in the foreground.
///  2. AlarmManager fires the package's receiver at the scheduled wall-clock
///     time — exact when the OS allows, inexact fallback otherwise.
///  3. The receiver shows the notification and RE-ARMS ITSELF for the next
///     day. The chain never depends on the app being opened again, nor on
///     the Flutter engine.
///  4. A boot receiver re-seeds the chain after device reboot / app update.
///
/// Branding is resolved per-app by resource name — each host app drops in:
///   * `drawable/ic_notification`  — white silhouette (status-bar small icon;
///     the system tints it, so use alpha-only art)
///   * `drawable/notification_face` — full-color brand mark (large icon)
///   * `res/values/meowmin_notifications.xml` — optional channel
///     name/description overrides (see the README)
class MeowminNotifications {
  MeowminNotifications._();

  static const MethodChannel _channel =
      MethodChannel('com.meowmin.notifications/reminders');

  /// Schedule (or re-schedule) both daily reminders with [config].
  ///
  /// Safe to call on every app launch: alarms are FLAG_UPDATE_CURRENT, so
  /// this always converges to exactly one pending chain per reminder.
  /// Returns false when the native side is unavailable (e.g. non-Android).
  static Future<bool> schedule(MeowminReminderConfig config) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'schedule',
        config.toMap(),
      );
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Cancel both daily alarms and remove any posted reminder notifications.
  static Future<bool> cancel() async {
    try {
      final ok = await _channel.invokeMethod<bool>('cancel');
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Debug proof sequence (Android): 1 immediate notification + 3 one-off
  /// alarms at +10/+20/+30s. Tests the full chain — display, permission,
  /// AlarmManager — without waiting for a wall-clock slot.
  ///
  /// If the immediate one shows but the 3 alarms don't, the OS/OEM is
  /// blocking alarms (battery optimization), not the code.
  static Future<bool> fireTestSequence({
    String title = '🔔 Test 0/3 — immediate',
    String body = 'Native display works. 3 alarms follow at 10s/20s/30s.',
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'fireTestSequence',
        {'title': title, 'body': body},
      );
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Show a single notification right now (no alarm involved). Useful for
  /// debug buttons ("fire the day notification") and UI previews.
  ///
  /// [isMorning] picks which stored config title/body to render. With
  /// [dedupe] true, returns false and shows nothing when that reminder was
  /// already delivered today by any path (alarm/push) — used by the FCM
  /// on-message handler to defer to the alarm chain.
  static Future<bool> showNow({required bool isMorning, bool dedupe = false}) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'showNow',
        {'isMorning': isMorning, 'dedupe': dedupe},
      );
      return ok ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
