import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/constants.dart';

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

  /// Server verdict cache: set when the backend reports this device already
  /// burned its trial on another uid (reinstall + new login). Overrides the
  /// local clock — denied means expired, never fresh.
  static const String _serverDeniedKey = 'server_trial_denied';
  /// Local trial started while offline; enforce against the server on next
  /// online launch (offline grace, not offline freedom).
  static const String _serverPendingKey = 'server_trial_pending';
  /// High-water mark of the device clock. All trial/grace elapsed-time math
  /// runs against this instead of the live clock, so setting the clock back
  /// can never re-open a closed window (rollback bypass).
  static const String _maxSeenNowKey = 'trial_max_seen_now_ms';

  /// Post-expiry grace: after a real Max subscription lapses, the user gets
  /// 3 days free again (dismissable paywall), just like the first trial.
  /// Set once on the active->inactive transition; cleared on repurchase.
  static const String _hadSubKey = 'had_max_subscription';
  static const String _graceStartKey = 'post_expiry_grace_start_ms';
  static const Duration _graceDuration = Duration(days: 3);

  /// Whether this device ever held a Max subscription. Used by the
  /// never-subscribed streak gate (streak>3 → expired hard lock).
  static Future<bool> hasEverSubscribed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_hadSubKey) ?? false;
    } catch (_) {
      return false;
    }
  }

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
    // Server-denied devices count as "started" so callers route to the
    // expired hard gate instead of minting a fresh trial.
    if (await isServerDenied()) return true;
    final prefs = await SharedPreferences.getInstance();
    final key = await _startKey();
    await _migrateIfNeeded(prefs, key);
    return prefs.getInt(key) != null;
  }

  /// Monotonic-ish now: the live clock, but never lower than the highest
  /// value ever observed on this install. Clock rollback (manual or a
  /// restore-from-backup) therefore cannot shrink elapsed time.
  static Future<int> _effectiveNowMs() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final prev = prefs.getInt(_maxSeenNowKey) ?? 0;
    if (now > prev) {
      await prefs.setInt(_maxSeenNowKey, now);
      return now;
    }
    return prev;
  }

  /// Whether the 3-day trial is currently active (dismissable window).
  /// A server denial always wins over the local clock.
  static Future<bool> isActive() async {
    if (await isServerDenied()) return false;
    final startMs = await _getStartMs();
    if (startMs == null) return false;
    return await _effectiveNowMs() - startMs < _trialDuration.inMilliseconds;
  }

  /// Whether the server denied this device a trial (consumed on another uid).
  static Future<bool> isServerDenied() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_serverDeniedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Record the server trial clock. Idempotent — safe to call at onboarding
  /// finale and defensively at launch. Offline failures leave the local
  /// clock running and flag a pending sync (grace, enforced next online).
  static Future<void> ensureServerTrial() async {
    try {
      final deviceId = await installId();
      final response = await http
          .post(
            Uri.parse('${AppConstants.backendUrl}/trial/start'),
            headers: await ApiClient.postHeaders(),
            body: jsonEncode({'device_id': deviceId}),
          )
          .timeout(const Duration(seconds: 15));
      final prefs = await SharedPreferences.getInstance();
      if (response.statusCode != 200) {
        await prefs.setBool(_serverPendingKey, true);
        return;
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['started'] == true) {
        await prefs.setBool(_serverDeniedKey, false);
        await prefs.setBool(_serverPendingKey, false);
        // Adopt the server-authoritative trial start. The server clock is
        // monotonic truth: taking min(server, local) means a wiped-prefs
        // reinstall resumes the ORIGINAL clock, and a rolled-back device
        // clock cannot re-open an expired trial.
        final serverStart = body['trialStart'];
        if (serverStart is num && serverStart > 0) {
          final key = await _startKey();
          final local = prefs.getInt(key);
          if (local == null || serverStart.toInt() < local) {
            await prefs.setInt(key, serverStart.toInt());
            debugPrint('[LocalTrial] Adopted server trial start');
          }
        }
      } else if (body['reason'] == 'device_claimed' || body['trialActive'] == false) {
        await prefs.setBool(_serverDeniedKey, true);
        await prefs.setBool(_serverPendingKey, false);
        debugPrint('[LocalTrial] Server denied trial: device already claimed');
      }
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_serverPendingKey, true);
      } catch (_) {}
    }
  }

  /// Whether the trial has expired (hard-gate territory).
  static Future<bool> isExpired() async {
    final startMs = await _getStartMs();
    if (startMs == null) return false;
    return await _effectiveNowMs() - startMs >= _trialDuration.inMilliseconds;
  }

  /// Remaining trial duration. [Duration.zero] when expired or not started.
  static Future<Duration> remaining() async {
    final startMs = await _getStartMs();
    if (startMs == null) return Duration.zero;
    final left = _trialDuration.inMilliseconds -
        (await _effectiveNowMs() - startMs);
    return left > 0 ? Duration(milliseconds: left) : Duration.zero;
  }

  /// Whether the user should see the paywall on launch (trial started,
  /// active or expired; already-subscribed users are filtered by callers).
  static Future<bool> shouldShowPaywall() => hasStarted();

  /// Whether a free-tier moment (journal saved / deck revealed) should
  /// surface the paywall. Dismissability is the caller's decision.
  static Future<bool> shouldTriggerForMoment() => hasStarted();

  /// Call on every launch/resume with the live subscription state.
  /// Tracks ever-subscribed so the first active->inactive flip arms a
  /// one-shot 3-day grace window. Repurchase clears the window.
  static Future<void> syncSubscriptionState(bool isSubscribed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isSubscribed) {
        await prefs.setBool(_hadSubKey, true);
        await prefs.remove(_graceStartKey);
        return;
      }
      final had = prefs.getBool(_hadSubKey) ?? false;
      if (!had) return;
      if (prefs.getInt(_graceStartKey) == null) {
        await prefs.setInt(
          _graceStartKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        debugPrint('[LocalTrial] Post-expiry grace started (3d free again)');
      }
    } catch (_) {}
  }

  /// Whether the 3-day post-expiry grace window is currently active.
  /// Paid users earned this — server-denial never blocks it.
  static Future<bool> isInPostExpiryGrace() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final had = prefs.getBool(_hadSubKey) ?? false;
      if (!had) return false;
      final startMs = prefs.getInt(_graceStartKey);
      if (startMs == null) return false;
      return await _effectiveNowMs() - startMs < _graceDuration.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  /// Remaining grace duration. [Duration.zero] when not in grace.
  static Future<Duration> graceRemaining() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startMs = prefs.getInt(_graceStartKey);
      if (startMs == null) return Duration.zero;
      final left = _graceDuration.inMilliseconds -
          (await _effectiveNowMs() - startMs);
      return left > 0 ? Duration(milliseconds: left) : Duration.zero;
    } catch (_) {
      return Duration.zero;
    }
  }

  /// Dismissable window: first 3-day trial OR 3-day post-expiry grace.
  static Future<bool> isSoftWindow() async {
    if (await isActive()) return true;
    return isInPostExpiryGrace();
  }

  /// Hard-gate territory: trial started, trial over, grace over.
  /// Callers must still filter subscribed users first.
  static Future<bool> isPastGrace() async {
    if (!await hasStarted()) return false;
    if (await isSoftWindow()) return false;
    return true;
  }

  // ── Resume-paywall pacing ──────────────────────────────────────────────
  // Dismissing the native paywall sheet returns to the Flutter activity with
  // a `resumed` event. Without pacing, an every-resume gate relaunches the
  // sheet the instant it is dismissed. Two guards break the loop:
  // 1. real backgrounding (the app was actually away, not just behind the
  //    paywall sheet or a transient overlay), tracked by callers via
  //    timestamps — see [_resumeMinBackground];
  // 2. a dismiss cooldown — at most one resume paywall per window.
  static const String _resumePaywallLastKey = 'launch_paywall_last_ms';
  static const Duration resumePaywallCooldown = Duration(minutes: 30);
  // A relaunch counts once the app was actually away (not just behind a
  // sheet or transient overlay). Sheet open/close is tracked separately by
  // callers, so this stays short.
  static const Duration resumeMinBackground = Duration(seconds: 10);
  // Resumes inside this window after any paywall sheet closed are the
  // sheet's own dismiss — never a relaunch.
  static const Duration resumePostSheetGrace = Duration(seconds: 5);

  /// Shared sheet tracking (splash, moments and MainScreen all present
  /// sheets): while true, or just after a close, resumes are the sheet's
  /// own dismiss — never a bg->fg relaunch.
  static bool sheetOpen = false;
  static DateTime? lastSheetClosed;

  /// Record that a soft paywall was just presented (cold launch or resume).
  static Future<void> notePaywallShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _resumePaywallLastKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// Whether enough time passed since the last soft paywall to show another
  /// one on resume. Cold launches and aha moments are NOT gated by this.
  static Future<bool> resumePaywallDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_resumePaywallLastKey) ?? 0;
      return DateTime.now().millisecondsSinceEpoch - last >=
          resumePaywallCooldown.inMilliseconds;
    } catch (_) {
      return true;
    }
  }

  static Future<int?> _getStartMs() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _startKey();
    await _migrateIfNeeded(prefs, key);
    return prefs.getInt(key);
  }
}
