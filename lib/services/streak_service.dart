import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'analytics_protocol.dart';
import 'analytics_service.dart';
import 'invite_service.dart';
import '../core/constants.dart';

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
  static const _shieldBalanceKey = 'shield_balance';

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

  static Future<int> getShieldBalance() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.backendUrl}/subscription/shields'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final shields = data['shields'] as int? ?? 0;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_shieldBalanceKey, shields);
        return shields;
      }
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_shieldBalanceKey) ?? 0;
  }

  static Future<int> consumeShields(int daysGap) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.backendUrl}/shop/shield-consume'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'daysGap': daysGap}),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final remaining = data['remaining'] as int? ?? 0;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_shieldBalanceKey, remaining);
        return data['consumed'] as int? ?? 0;
      }
    } catch (_) {}
    return 0;
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
      if (lastDate == yesterday) {
        streak += 1;
      } else {
        final gap = normalizedToday.difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays;
        if (gap > 1) {
          final consumed = await consumeShields(gap);
          if (consumed > 0) {
            _analytics.logEvent('streak_shield_used', params: {
              'gap': gap.toString(),
              'consumed': consumed.toString(),
            });
            streak = streak;
          } else {
            streak = 1;
          }
        } else {
          streak = 1;
        }
      }
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

    // Log habit tick: active days in last 7 days + streak for WSR tracking
    try {
      final last7 = await getLast7Days();
      final activeDays = last7.where((d) => d).length;
      final prefs = await SharedPreferences.getInstance();
      final totalCount = prefs.getInt('habit_tick_journal_count') ?? 0;
      _analytics.logHabitTick(
        activeDaysLast7: activeDays,
        streakLen: result.streak,
        totalJournalCount: totalCount,
      );
    } catch (_) {}

    // Push the new streak to the backend so a linked friend can read it for
    // the shared "shielded" streak. Fire-and-forget.
    unawaited(InviteService.pushMyStreak(result.streak));
  }

  /// The streak shown to the user: the max of their own streak and a linked
  /// friend's streak (so a missed day is shielded by the friend's higher one).
  static Future<int> getDisplayStreak() async {
    final local = await getStreak();
    final friend = await InviteService.getFriendStreakCached();
    return max(local, friend);
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
