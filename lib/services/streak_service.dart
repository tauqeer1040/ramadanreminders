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

  /// Locally armed shields from Streak Shield purchases. Each entry is
  /// `{'a': armedAtMs, 'p': preservedStreak}`. An armed shield auto-fires
  /// when a gap resets the streak, but only within [_armedTtl].
  static const _armedShieldsKey = 'armed_shields';
  static const _armedTtl = Duration(days: 2);

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

  static Future<int> consumeShields(int daysGap) async {    try {
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

  /// Reads armed shields, dropping ones older than [_armedTtl].
  static Future<List<Map<String, int>>> _validArmedShields() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_armedShieldsKey);
    if (raw == null || raw.isEmpty) return [];
    final now = DateTime.now().millisecondsSinceEpoch;
    final valid = <Map<String, int>>[];
    try {
      final decoded = json.decode(raw) as List;
      for (final e in decoded) {
        final m = Map<String, dynamic>.from(e as Map);
        final armedAt = (m['a'] as num?)?.toInt() ?? 0;
        final preserved = (m['p'] as num?)?.toInt() ?? 0;
        if (preserved > 1 &&
            now - armedAt <= _armedTtl.inMilliseconds) {
          valid.add({'a': armedAt, 'p': preserved});
        }
      }
    } catch (_) {}
    await prefs.setString(
      _armedShieldsKey,
      jsonEncode(valid.map((e) => {'a': e['a'], 'p': e['p']}).toList()),
    );
    return valid;
  }

  /// Number of live (unexpired) armed shields. Used for the `Use XN` banner.
  static Future<int> getArmedShieldCount() async {
    return (await _validArmedShields()).length;
  }

  /// Arms a shield preserving the current streak. Called after a verified
  /// $0.99 purchase while the streak is still alive (> 1).
  static Future<void> armShield(int preservedStreak) async {
    if (preservedStreak <= 1) return;
    final prefs = await SharedPreferences.getInstance();
    final valid = await _validArmedShields();
    valid.add({
      'a': DateTime.now().millisecondsSinceEpoch,
      'p': preservedStreak,
    });
    await prefs.setString(_armedShieldsKey, jsonEncode(valid));
    _analytics.logEvent('streak_shield_armed',
        params: {'preserved': preservedStreak.toString()});
  }

  /// Consumes one armed shield for auto-fire. Returns the preserved streak
  /// to restore, or null when no live armed shield exists. Keeps the server
  /// balance in sync (purchases increment it via shield-grant).
  static Future<int?> consumeArmedShield() async {
    final valid = await _validArmedShields();
    if (valid.isEmpty) return null;
    valid.sort((a, b) => b['p']!.compareTo(a['p']!));
    final preserved = valid.removeAt(0)['p']!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_armedShieldsKey, jsonEncode(valid));
    // Server decrements its balance by exactly 1 to mirror the local arm.
    await consumeShields(1);
    return preserved;
  }

  /// Longest consecutive-day run in the recorded activity dates. This is
  /// the "longest previous streak" the manual Restore button repairs to.
  static Future<int> longestRun() async {
    final prefs = await SharedPreferences.getInstance();
    return longestRunOf(prefs.getStringList(_activityDatesKey) ?? []);
  }

  /// Pure longest-run computation over `yyyy-MM-dd` date strings.
  /// Unit-testable; invalid entries are ignored.
  static int longestRunOf(List<String> dateStrs) {
    final days = <DateTime>{};
    for (final d in dateStrs) {
      try {
        final parsed = DateTime.parse(d);
        days.add(DateTime(parsed.year, parsed.month, parsed.day));
      } catch (_) {}
    }
    if (days.isEmpty) return 1;
    final sorted = days.toList()..sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]).inDays == 1) {
        run += 1;
        if (run > best) best = run;
      } else {
        run = 1;
      }
    }
    return best;
  }

  /// Manual restore: consumes one armed shield and repairs the streak to
  /// the longest recorded run. Returns the restored streak, or null when
  /// there is nothing to restore (no shields, or streak already healthy).
  static Future<int?> restoreToLongest() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_streakKey) ?? 1;
    final longest = await longestRun();
    if (longest <= 1 || current >= longest) return null;
    final valid = await _validArmedShields();
    if (valid.isEmpty) return null;
    valid.sort((a, b) => b['p']!.compareTo(a['p']!));
    valid.removeAt(0);
    await prefs.setString(_armedShieldsKey, jsonEncode(valid));
    await consumeShields(1);

    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T')[0];
    final dates = (prefs.getStringList(_activityDatesKey) ?? []).toList();
    if (!dates.contains(todayStr)) {
      dates.add(todayStr);
      await prefs.setStringList(_activityDatesKey, dates);
    }
    await prefs.setInt(_streakKey, longest);
    await prefs.setString(_lastActivityDateKey, todayStr);
    _analytics.logEvent('streak_shield_restored',
        params: {'streak': longest.toString()});
    unawaited(InviteService.pushMyStreak(longest));
    return longest;
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
          // Armed Streak Shields fire first: restore the preserved number.
          final armedRestore = await consumeArmedShield();
          if (armedRestore != null) {
            _analytics.logEvent('streak_shield_used', params: {
              'gap': gap.toString(),
              'restored': armedRestore.toString(),
            });
            streak = armedRestore;
          } else {
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

  static String _fmtDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Normalizes a raw day string to `yyyy-MM-dd`. Accepts bare dates and
  /// full ISO timestamps (date part before `T`); anything else is rejected.
  /// Unit-testable; never throws.
  static String? normalizeDay(String raw) {
    try {
      final s = raw.trim();
      if (s.isEmpty) return null;
      final head = s.contains('T') ? s.split('T')[0] : (s.length >= 10 ? s.substring(0, 10) : s);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(head)) return null;
      // Round-trip validates ranges: DateTime.parse overflows (month 13 →
      // next January) instead of throwing, so a mismatch means invalid.
      if (_fmtDay(DateTime.parse(head)) != head) return null;
      return head;
    } catch (_) {
      return null;
    }
  }

  /// Pure trailing-day run over `yyyy-MM-dd` strings ending today (or
  /// yesterday when today is absent). Returns 0 when the run is not live.
  /// Unit-testable; never throws.
  static int trailingRunOf(Iterable<String> dateStrs, DateTime now) {
    try {
      final days = <String>{};
      for (final raw in dateStrs) {
        final day = normalizeDay(raw);
        if (day != null) days.add(day);
      }
      if (days.isEmpty) return 0;
      final today = DateTime(now.year, now.month, now.day);
      var cursor = days.contains(_fmtDay(today))
          ? today
          : today.subtract(const Duration(days: 1));
      var run = 0;
      while (days.contains(_fmtDay(cursor))) {
        run++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return run;
    } catch (_) {
      return 0;
    }
  }

  /// Merges externally-known active days (e.g. past local journal dates)
  /// into `streak_activity_dates` and adopts the trailing run when it beats
  /// the stored streak. Max-wins and forward-only, mirroring the server
  /// restore: never shrinks a healthy streak, never moves
  /// `last_activity_date` backwards, never resurrects a dead run (a
  /// non-live trailing run yields 0 and leaves the counter untouched).
  /// Returns the resulting streak. Never throws.
  static Future<int> adoptActivityDates(Iterable<String> rawDays) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_activityDatesKey) ?? const <String>[];
      final merged = <String>{...existing};
      for (final raw in rawDays) {
        final day = normalizeDay(raw);
        if (day != null) merged.add(day);
      }
      final current = prefs.getInt(_streakKey) ?? 1;
      if (merged.isEmpty) return current < 1 ? 1 : current;
      final sorted = merged.toList()..sort();
      await prefs.setStringList(_activityDatesKey, sorted);
      final run = trailingRunOf(sorted, DateTime.now());
      if (run > 0) {
        if (run > current) await prefs.setInt(_streakKey, run);
        final curLast = prefs.getString(_lastActivityDateKey);
        final newest = sorted.last;
        if (curLast == null || newest.compareTo(curLast) > 0) {
          await prefs.setString(_lastActivityDateKey, newest);
        }
        return max(run, current);
      }
      return current < 1 ? 1 : current;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final fallback = prefs.getInt(_streakKey) ?? 1;
        return fallback < 1 ? 1 : fallback;
      } catch (_) {
        return 1;
      }
    }
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
