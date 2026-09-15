import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import 'local_trial_service.dart';
import 'revenuecat_service.dart';

/// A server-side entitlement verdict (`GET /entitlement`).
class EntitlementVerdict {
  final bool active;
  final String reason;

  /// Reasons the backend uses to positively deny access.
  static const Set<String> deniedReasons = {
    'trial_expired',
    'device_claimed',
    'no_trial_stale',
  };

  const EntitlementVerdict({
    required this.active,
    required this.reason,
  });

  factory EntitlementVerdict.fromJson(Map<String, dynamic> json) {
    return EntitlementVerdict(
      active: json['active'] == true,
      reason: (json['reason'] as String?) ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() => {'active': active, 'reason': reason};

  bool get isSubscription => reason == 'subscription';

  /// A definite denial (as opposed to "server unreachable / unknown").
  bool get isDenied => !active && deniedReasons.contains(reason);
}

/// Server-authoritative gate for the 3-day trial.
///
/// The local trial clock (`LocalTrialService`) can be reset by wiping app
/// data, so it is only ever a fallback: whenever the backend can be reached
/// its verdict wins. Two properties keep that honest:
///
/// * **An active store entitlement always unlocks.** Paying users must never
///   be locked out by a network hiccup, a lagging DB row or a stale cache.
/// * **A denial is sticky.** Once the server says the trial is over, no
///   amount of local clock manipulation re-opens the app; only a fresh
///   verdict (a purchase) does.
class EntitlementService {
  static const String _cacheKey = 'entitlement_cache_json';
  static const String _cacheAtKey = 'entitlement_cache_at_ms';

  /// How long a cached *allow* verdict is trusted before the local clock
  /// takes over again (a denial never expires).
  static const Duration maxAllowAge = Duration(hours: 12);

  /// Minimum gap between network verdicts (an app can hit the gate on
  /// launch, resume and every editor open).
  static const Duration _refetchInterval = Duration(seconds: 60);
  static const Duration _timeout = Duration(seconds: 5);

  static EntitlementVerdict? _memo;
  static DateTime? _memoAt;

  /// Test seam: replaces the network verdict lookup.
  @visibleForTesting
  static Future<EntitlementVerdict?> Function()? fetchOverride;

  static String? _currentUid() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Fetches a fresh verdict, or null when the server is unreachable.
  /// Never throws.
  static Future<EntitlementVerdict?> fetchVerdict() async {
    final override = fetchOverride;
    if (override != null) return override();

    final uid = _currentUid();
    if (uid == null || uid.isEmpty) return null;

    final memoAt = _memoAt;
    if (_memo != null &&
        memoAt != null &&
        DateTime.now().difference(memoAt) < _refetchInterval) {
      return _memo;
    }

    try {
      final headers = await ApiClient.authHeaders();
      final res = await http
          .get(
            Uri.parse('${AppConstants.backendUrl}/entitlement'),
            headers: headers,
          )
          .timeout(_timeout);
      if (res.statusCode != 200) {
        debugPrint('[Entitlement] HTTP ${res.statusCode}, using cache/local');
        return null;
      }
      final verdict = EntitlementVerdict.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );
      _memo = verdict;
      _memoAt = DateTime.now();
      debugPrint('[Entitlement] server verdict: active=${verdict.active} reason=${verdict.reason}');
      return verdict;
    } catch (e) {
      debugPrint('[Entitlement] fetch failed (using cache/local): $e');
      return null;
    }
  }

  static Future<void> cache(EntitlementVerdict verdict) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(verdict.toJson()));
      await prefs.setInt(
        _cacheAtKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  static Future<EntitlementVerdict?> cached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      return EntitlementVerdict.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Clears the cached denial — called after a purchase so the next gate
  /// check cannot be held shut by an old verdict.
  static Future<void> clear() async {
    resetMemo();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheAtKey);
    } catch (_) {}
  }

  @visibleForTesting
  static void resetMemo() {
    _memo = null;
    _memoAt = null;
  }

  /// The gate decision: true means the expired wall belongs on screen.
  ///
  /// [subscribed] lets callers that already resolved the store entitlement
  /// skip a duplicate RevenueCat lookup. [uidOverride] is a test seam.
  static Future<bool> shouldLock({
    bool? subscribed,
    @visibleForTesting String? uidOverride,
  }) async {
    final uid = uidOverride ?? _currentUid();
    // Signed out (onboarding, splash before auth): the local flow owns the
    // decision, there is no server account to judge.
    if (uid == null || uid.isEmpty) return false;

    // 1) An active store entitlement always wins.
    bool isSub;
    if (subscribed != null) {
      isSub = subscribed;
    } else {
      try {
        isSub = await RevenueCatService.instance.isSubscribed();
      } catch (_) {
        isSub = false;
      }
    }
    if (isSub) return false;

    // 2) Fresh server verdict.
    final fresh = await fetchVerdict();
    if (fresh != null) {
      await cache(fresh);
      return !fresh.active;
    }

    // 3) Cached verdict — denials are sticky, allows decay.
    final cachedVerdict = await cached();
    if (cachedVerdict != null) {
      if (!cachedVerdict.active) return true;
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(_cacheAtKey);
      if (at != null &&
          DateTime.now().millisecondsSinceEpoch - at <
              maxAllowAge.inMilliseconds) {
        return false;
      }
    }

    // 4) Offline with nothing usable: fall back to the local clock, which
    // still has to say the trial is over before we lock (keeps a genuine
    // first-run-offline user working until the server can rule).
    try {
      return await LocalTrialService.isPastGrace();
    } catch (_) {
      return false;
    }
  }
}
