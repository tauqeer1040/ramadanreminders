import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  static const _streakKey = 'streak';
  static const _lastActivityDateKey = 'last_activity_date';
  static const _activityDatesKey = 'streak_activity_dates';

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

  static Future<void> checkAndUpdateStreak() async {
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
    } else if (lastDateStr == todayStr) {
      // already tracked, no change
    } else {
      final lastDate = DateTime.parse(lastDateStr);
      final normalizedToday = DateTime(today.year, today.month, today.day);
      final yesterday = normalizedToday.subtract(const Duration(days: 1));

      if (lastDate == yesterday) {
        streak++;
      } else {
        streak = 1;
      }
    }

    if (streak < 1) streak = 1;

    await prefs.setInt(_streakKey, streak);
    await prefs.setString(_lastActivityDateKey, todayStr);
  }

  static Future<void> recordActivity() async {
    await checkAndUpdateStreak();
  }
}
