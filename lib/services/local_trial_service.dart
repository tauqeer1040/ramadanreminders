import 'dart:io' show Platform;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local 3-day free trial tied to a stable INSTALL identity so the clock
/// survives reinstalls: dismissable paywall for the first 3 days, hard
/// non-dismissable gate afterwards — even if the app is wiped and
/// reinstalled (Android: ANDROID_ID is stable across reinstalls for the
/// same signing key).
///
/// Legacy clocks (device-global + per-uid keys) are adopted once so
/// existing installs keep their original start time.
class LocalTrialService {
  static const String _legacyTrialStartKey = 'local_trial_start_ms';
  static const String _installIdKey = 'meowmin_install_id';
  static const Duration _trialDuration = Duration(days: 3);

  static String? _cachedInstallId;

  /// Stable per-install id. SSAID on Android; elsewhere a random id stored
  /// in prefs (best effort — the reinstall-proof guarantee is Android).
  static Future<String> installId() async {
    if (_cachedInstallId != null) return _cachedInstallId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_installIdKey);
    if (id == null) {
      try {
        if (!kIsWeb && Platform.isAndroid) {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          final said = androidInfo.id; // SSAID
          if (said.isNotEmpty && said != 'unknown') id = 'aid:$said';
        }
      } catch (_) {}
      id ??=
          'rnd:${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 32)}';
      await prefs.setString(_installIdKey, id);
    }
    return _cachedInstallId = id;
  }

  static String? _currentUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Trial clock key: install-scoped. A reinstall gives fresh prefs but
  /// the same SSAID, so the ORIGINAL start time is read back — no fresh
  /// 3 days.
  static Future<String> _startKey() async {
    final install = await installId();
    final uid = _currentUid();
    return uid == null || uid.isEmpty
        ? 'local_trial_start_install_$install'
        : 'local_trial_start_install_${install}_uid_$uid';
  }

  /// Adopt legacy clocks (device-global / per-uid) into install scope once.
  static Future<void> _migrateIfNeeded(
    SharedPreferences prefs,
    String key,
  ) async {
    if (prefs.getInt(key) != null) return;
    final uid = _currentUid();
    final legacyPerUid = (uid == null || uid.isEmpty)
        ? null
        : prefs.getInt('local_trial_start_ms_$uid');
    final adopted = legacyPerUid ?? prefs.getInt(_legacyTrialStartKey);
    if (adopted != null) {
      await prefs.setInt(key, adopted);
      debugPrint('[LocalTrial] Adopted legacy trial start into install scope');
    }
  }

  /// Start the 3-day trial (first qualifying moment for this install).
  static Future<void> startTrial() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _startKey();
    await _migrateIfNeeded(prefs, key);
    if (prefs.getInt(key) == null) {
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
      debugPrint('[LocalTrial] Trial started');
    }
  }

  static Future<bool> hasStarted() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _startKey();
    await _migrateIfNeeded(prefs, key);
    return prefs.getInt(key) != null;
  }

  /// Whether the 3-day trial is currently active (dismissable window).
  static Future<bool> isActive() async {
    final startMs = await _getStartMs();
    if (startMs == null) return false;
    return DateTime.now().millisecondsSinceEpoch - startMs <
        _trialDuration.inMilliseconds;
  }

  /// Whether the trial has expired (hard-gate territory).
  static Future<bool> isExpired() async {
    final startMs = await _getStartMs();
    if (startMs == null) return false;
    return DateTime.now().millisecondsSinceEpoch - startMs >=
        _trialDuration.inMilliseconds;
  }

  /// Remaining trial duration. [Duration.zero] when expired or not started.
  static Future<Duration> remaining() async {
    final startMs = await _getStartMs();
    if (startMs == null) return Duration.zero;
    final left = _trialDuration.inMilliseconds -
        (DateTime.now().millisecondsSinceEpoch - startMs);
    return left > 0 ? Duration(milliseconds: left) : Duration.zero;
  }

  /// Whether the user should see the paywall on launch (trial started,
  /// active or expired; already-subscribed users are filtered by callers).
  static Future<bool> shouldShowPaywall() => hasStarted();

  /// Whether a free-tier moment (journal saved / deck revealed) should
  /// surface the paywall. Dismissability is the caller's decision.
  static Future<bool> shouldTriggerForMoment() => hasStarted();

  static Future<int?> _getStartMs() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _startKey();
    await _migrateIfNeeded(prefs, key);
    return prefs.getInt(key);
  }
}
