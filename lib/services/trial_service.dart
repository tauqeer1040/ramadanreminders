import 'package:shared_preferences/shared_preferences.dart';

class TrialService {
  static const _trialStartKey = 'trial_start';
  static const _trialDays = 3;

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
}
