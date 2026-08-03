import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ramadan_reflections/services/streak_service.dart';

void main() {
  group('isPrime', () {
    test('returns false for numbers < 2', () {
      expect(StreakService.isPrime(0), false);
      expect(StreakService.isPrime(1), false);
    });

    test('returns true for prime numbers', () {
      const primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37];
      for (final p in primes) {
        expect(StreakService.isPrime(p), true, reason: '$p should be prime');
      }
    });

    test('returns false for composite numbers', () {
      const composites = [4, 6, 8, 9, 10, 12, 14, 15, 16, 18, 20, 21, 22, 24, 25, 26, 27, 28, 30];
      for (final c in composites) {
        expect(StreakService.isPrime(c), false, reason: '$c should not be prime');
      }
    });
  });

  group('checkAndUpdateStreak', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('first activity sets streak to 1', () async {
      final result = await StreakService.checkAndUpdateStreak();
      expect(result.streak, 1);
      expect(result.isMilestone, false);
      expect(result.hasPrimeReward, false);
      expect(result.milestoneStreak, isNull);
    });

    test('consecutive day increments streak', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'streak': 1,
        'last_activity_date': yesterday.toIso8601String().split('T')[0],
        'streak_activity_dates': <String>[yesterday.toIso8601String().split('T')[0]],
      });

      final result = await StreakService.checkAndUpdateStreak();
      expect(result.streak, 2);
    });

    test('missed day resets streak to 1', () async {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      SharedPreferences.setMockInitialValues({
        'streak': 5,
        'last_activity_date': twoDaysAgo.toIso8601String().split('T')[0],
        'streak_activity_dates': <String>[twoDaysAgo.toIso8601String().split('T')[0]],
      });

      final result = await StreakService.checkAndUpdateStreak();
      expect(result.streak, 1);
    });
  });

  group('getLast7Days', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns all false when no activity', () async {
      final days = await StreakService.getLast7Days();
      expect(days.length, 7);
      expect(days.every((d) => d == false), true);
    });

    test('marks today as active', () async {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      SharedPreferences.setMockInitialValues({
        'streak_activity_dates': <String>[todayStr],
      });
      final days = await StreakService.getLast7Days();
      expect(days.last, true);
    });
  });
}
