import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local 3-day free trial for users who skip the $1 qualifying offer.
///
/// - Trial starts when user taps "Skip" on the qualifying page.
/// - During trial: paywall shows on every app launch, dismissable.
/// - After 3 days: hard paywall, non-dismissable.
class LocalTrialService {
  static const String _trialStartKey = 'local_trial_start_ms';
  static const Duration _trialDuration = Duration(days: 3);

  /// Start the 3-day trial. Called when user skips the qualifying offer.
  static Future<void> startTrial() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_trialStartKey) == null) {
      await prefs.setInt(_trialStartKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('[LocalTrial] Trial started');
    }
  }

  /// Whether the trial has been started (regardless of expiry).
  static Future<bool> hasStarted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_trialStartKey) != null;
  }

  /// Whether the 3-day trial is currently active.
  static Future<bool> isActive() async {
    final startMs = await _getStartMs();
    if (startMs == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
    return elapsed < _trialDuration.inMilliseconds;
  }

  /// Whether the trial has expired (started but 3 days have passed).
  static Future<bool> isExpired() async {
    final startMs = await _getStartMs();
    if (startMs == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
    return elapsed >= _trialDuration.inMilliseconds;
  }

  /// Remaining trial duration. Returns [Duration.zero] if expired or not started.
  static Future<Duration> remaining() async {
    final startMs = await _getStartMs();
    if (startMs == null) return Duration.zero;
    final elapsed = DateTime.now().millisecondsSinceEpoch - startMs;
    final remaining = _trialDuration.inMilliseconds - elapsed;
    return remaining > 0 ? Duration(milliseconds: remaining) : Duration.zero;
  }

  /// Whether the user should see the paywall on launch.
  /// - true if trial is active (dismissable) or expired (hard paywall)
  /// - false if trial hasn't started yet or user is already subscribed
  static Future<bool> shouldShowPaywall() async {
    final started = await hasStarted();
    if (!started) return false;
    // Show paywall during active trial or after expiry
    return true;
  }

  static Future<int?> _getStartMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_trialStartKey);
  }
}
