import 'package:shared_preferences/shared_preferences.dart';

class TrialService {
  static const _trialStartKey = 'trial_start';
  static const _trialDays = 3;
  static const _graceMsKey = 'grace_remaining_ms';
  static const _initialGraceMs = 30 * 60 * 1000; // 30 minutes
  static const _launchCostMs = 1 * 60 * 1000;     // 1 minute per launch

  /// Initialize trial on first launch (no-op if already started).
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_trialStartKey)) {
      await prefs.setInt(_trialStartKey, DateTime.now().millisecondsSinceEpoch);
    }
  }

  /// Whether the trial is still active for an anonymous user.
  static Future<bool> isTrialActive() async {
    final prefs = await SharedPreferences.getInstance();
    final startMs = prefs.getInt(_trialStartKey);
    if (startMs == null) return false;
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    return DateTime.now().difference(start).inDays < _trialDays;
  }

  /// Days remaining in the trial (0–3). 0 if expired or not started.
  static Future<int> daysRemaining() async {
    final prefs = await SharedPreferences.getInstance();
    final startMs = prefs.getInt(_trialStartKey);
    if (startMs == null) return 0;
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    final elapsed = DateTime.now().difference(start).inDays;
    return (_trialDays - elapsed).clamp(0, _trialDays);
  }

  /// Whether the trial has expired (started but past 3 days).
  static Future<bool> isTrialExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final startMs = prefs.getInt(_trialStartKey);
    if (startMs == null) return false;
    final start = DateTime.fromMillisecondsSinceEpoch(startMs);
    return DateTime.now().difference(start).inDays >= _trialDays;
  }

  // ── Grace period (hard paywall bypass) ──────────────────────────────

  /// Initialize grace balance on first launch (no-op if already set).
  static Future<void> initializeGrace() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_graceMsKey)) {
      await prefs.setInt(_graceMsKey, _initialGraceMs);
    }
  }

  /// Deduct 1 minute for this launch. Returns remaining ms.
  static Future<int> deductLaunchCost() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_graceMsKey) ?? _initialGraceMs;
    final remaining = (current - _launchCostMs).clamp(0, _initialGraceMs);
    await prefs.setInt(_graceMsKey, remaining);
    return remaining;
  }

  /// Deduct real-time session usage. Returns remaining ms.
  static Future<int> consumeSessionMs(int elapsedMs) async {
    if (elapsedMs <= 0) return await getRemainingMs();
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_graceMsKey) ?? 0;
    final remaining = (current - elapsedMs).clamp(0, _initialGraceMs);
    await prefs.setInt(_graceMsKey, remaining);
    return remaining;
  }

  /// Remaining grace balance in ms.
  static Future<int> getRemainingMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_graceMsKey) ?? 0;
  }

  /// Whether the user has any grace remaining.
  static Future<bool> hasGraceRemaining() async {
    return await getRemainingMs() > 0;
  }
}
