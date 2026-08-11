import 'package:shared_preferences/shared_preferences.dart';
import 'analytics_protocol.dart';
import 'analytics_service.dart';

class StreakResult {
  final int streak;
  final bool isMilestone;
  final bool hasPrimeReward;
  final int? milestoneStreak;

  const StreakResult({
    required this.streak,
    this.isMilestone = false,
    this.hasPrimeReward = false,
    this.milestoneStreak,
  });
}

class StreakService {
  static const _streakKey = 'streak';
  static const _lastActivityDateKey = 'last_activity_date';
  static const _activityDatesKey = 'streak_activity_dates';
  static const _claimedPrimesKey = 'claimed_prime_rewards';

  static AnalyticsProtocol _analytics = AnalyticsService.instance;

  static void injectAnalytics(AnalyticsProtocol a) {
    _analytics = a;
  }

  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getInt(_streakKey) ?? 1;
    return val < 1 ? 1 : val;
  }

  static Future<List<bool>> getLast7Days() async {
    final prefs = await SharedPreferences.getInstance();
    final dates = prefs.getStringList(_activityDatesKey) ?? [];
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final result = List.filled(7, false);

    for (int i = 0; i < 7; i++) {
      final day = normalizedToday.subtract(Duration(days: 6 - i));
      final dayStr = day.toIso8601String().split('T')[0];
      if (dates.contains(dayStr)) {
        result[i] = true;
      }
    }

    return result;
  }

  static Future<StreakResult> checkAndUpdateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T')[0];
    final lastDateStr = prefs.getString(_lastActivityDateKey);
    int streak = prefs.getInt(_streakKey) ?? 1;

    final dates = (prefs.getStringList(_activityDatesKey) ?? []).toList();
    if (!dates.contains(todayStr)) {
      dates.add(todayStr);
      await prefs.setStringList(_activityDatesKey, dates);
    }

    if (lastDateStr == null) {
      streak = 1;
    } else if (lastDateStr != todayStr) {
      final lastDate = DateTime.parse(lastDateStr);
      final normalizedToday = DateTime(today.year, today.month, today.day);
      final yesterday = normalizedToday.subtract(const Duration(days: 1));
      streak = lastDate == yesterday ? streak + 1 : 1;
    }

    if (streak < 1) streak = 1;

    await prefs.setInt(_streakKey, streak);
    await prefs.setString(_lastActivityDateKey, todayStr);

    final isMilestone = streak > 1 && (isPrime(streak) || streak % 7 == 0);
    final hasReward = !isPrime(streak) ? false : () {
      final claimedKey = streak.toString();
      final claimed = prefs.getStringList(_claimedPrimesKey) ?? [];
      if (claimed.contains(claimedKey)) return false;
      claimed.add(claimedKey);
      prefs.setStringList(_claimedPrimesKey, claimed);
      return true;
    }();

    return StreakResult(
      streak: streak,
      isMilestone: isMilestone,
      hasPrimeReward: hasReward,
      milestoneStreak: isMilestone ? streak : null,
    );
  }

  static Future<void> recordActivity() async {
    final result = await checkAndUpdateStreak();
    if (result.isMilestone) {
      _analytics.logEvent('streak_milestone', params: {'streak': result.streak.toString()});
    }
    if (result.hasPrimeReward) {
      _analytics.logEvent('streak_prime_reward_claimed', params: {'streak': result.streak.toString()});
    }
    // Log streak for analytics
    try {
      _analytics.logStreakRecorded(result.streak);
    } catch (_) {}
  }

  static bool isPrime(int n) {
    if (n < 2) return false;
    for (int i = 2; i * i <= n; i++) {
      if (n % i == 0) return false;
    }
    return true;
  }

  static Future<bool> checkAndClaimPrimeReward() async {
    final prefs = await SharedPreferences.getInstance();
    final streak = prefs.getInt(_streakKey) ?? 1;
    if (!isPrime(streak)) return false;

    final claimed = prefs.getStringList(_claimedPrimesKey) ?? [];
    final key = streak.toString();
    if (claimed.contains(key)) return false;

    claimed.add(key);
    await prefs.setStringList(_claimedPrimesKey, claimed);
    _analytics.logEvent('streak_prime_reward_claimed', params: {'streak': streak.toString()});
    return true;
  }
}
