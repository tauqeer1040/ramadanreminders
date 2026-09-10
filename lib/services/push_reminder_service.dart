import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:meowmin_notifications/meowmin_notifications.dart' as meow;
import '../core/api_client.dart';
import '../core/constants.dart';

/// FCM push leg of the hybrid reminder delivery.
///
/// The backend cron sends a data-only message (`{type: reminder, kind:
/// morning|night}`) to every device whose LOCAL hour matches 8:00 / 22:00
/// (per-device UTC offset registered with the token). This service renders
/// it locally through the meowmin_notifications package — copy comes from
/// native prefs (cat name + name), so the server never needs personal data —
/// and the package's day-keyed dedupe means whichever leg fires second
/// (push or alarm) is a no-op. Tap → app open is handled by the package
/// builder for locally-rendered notifications.
///
/// Background entry point: [firebaseMessagingBackgroundHandler] must be
/// top-level (isolate entry) and annotated @pragma('vm:entry-point').
class PushReminderService {
  PushReminderService._();
  static bool _initialized = false;
  static String? _lastToken;

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Init messaging, register/refresh the token, wire handlers.
  /// Safe to call repeatedly; token registration is idempotent (server
  /// upserts) and cheap.
  static Future<void> init({required bool remindersEnabled}) async {
    if (!_supported || _initialized) return;
    _initialized = true;
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true, badge: true, sound: true,
      );

      // Background data messages → render locally (deduped vs alarm chain).
      FirebaseMessaging.onMessage.listen(_handleDataMessage);
      FirebaseMessaging.onMessageOpenedApp.listen((_) {
        // Tap → app already opens via the plugin's default behavior; this
        // hook is where a deep-link route could go later.
      });

      // Token rotation: re-register whenever FCM hands out a new token.
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _lastToken = token;
        _registerToken(token, remindersEnabled: remindersEnabled);
      });

      final token = await messaging.getToken();
      if (token != null && token != _lastToken) {
        _lastToken = token;
        await _registerToken(token, remindersEnabled: remindersEnabled);
      }
      debugPrint('[PushReminders] initialized, token registered');
    } catch (e) {
      debugPrint('[PushReminders] init failed: $e');
      _initialized = false;
    }
  }

  static Future<void> _handleDataMessage(RemoteMessage message) async {
    if (message.data['type'] != 'reminder') return;
    final isMorning = message.data['kind'] == 'morning';
    // dedupe=true: if the alarm chain already delivered today, this no-ops.
    final shown = await meow.MeowminNotifications.showNow(isMorning: isMorning, dedupe: true);
    debugPrint('[PushReminders] push received kind=${message.data['kind']} shown=$shown');
  }

  static Future<Map<String, dynamic>?> _post(String path, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.backendUrl}$path'),
        headers: await ApiClient.postHeaders(),
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('[PushReminders] $path -> ${response.statusCode}');
    } catch (e) {
      debugPrint('[PushReminders] $path failed: $e');
    }
    return null;
  }

  static Future<void> _registerToken(String token, {required bool remindersEnabled}) async {
    final res = await _post('/push/register', {
      'token': token,
      'platform': Platform.operatingSystem,
      'utcOffset': DateTime.now().timeZoneOffset.inMinutes,
      'remindersEnabled': remindersEnabled,
    });
    debugPrint('[PushReminders] register ok=${res != null}');
  }

  /// Reminders toggle changed → push the new state to the server so the
  /// cron stops/starts targeting this device.
  static Future<void> setRemindersEnabled(bool enabled) async {
    if (!_supported) return;
    await _post('/push/toggle', {'enabled': enabled});
  }

  /// Debug: ask the backend to fire a test reminder push to this account.
  static Future<bool> sendTestPush({bool night = false}) async {
    if (!_supported) return false;
    final res = await _post('/push/test', {'kind': night ? 'night' : 'morning'});
    return res != null;
  }
}

/// Background isolate entry: render the reminder locally even when the app
/// was killed. Uses the same package path + day-keyed dedupe.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] != 'reminder') return;
  final isMorning = message.data['kind'] == 'morning';
  try {
    await meow.MeowminNotifications.showNow(isMorning: isMorning, dedupe: true);
    debugPrint('[PushReminders] background push rendered kind=${message.data['kind']}');
  } catch (e) {
    debugPrint('[PushReminders] background render failed: $e');
  }
}
