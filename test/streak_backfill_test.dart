import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ramadan_reflections/services/streak_service.dart';

String _day(DateTime d) => d.toIso8601String().split('T')[0];

void main() {
  group('normalizeDay', () {
    test('accepts bare yyyy-MM-dd', () {
      expect(StreakService.normalizeDay('2026-09-14'), '2026-09-14');
    });

    test('accepts full ISO timestamp (date part)', () {
      expect(StreakService.normalizeDay('2026-09-14T08:31:00.000'), '2026-09-14');
    });

    test('accepts suffixed journal ids by date prefix', () {
      expect(StreakService.normalizeDay('2026-09-14abc'), '2026-09-14');
    });

    test('rejects garbage, empty and impossible dates', () {
      expect(StreakService.normalizeDay(''), isNull);
      expect(StreakService.normalizeDay('not-a-date'), isNull);
      expect(StreakService.normalizeDay('2026-13-45'), isNull);
      expect(StreakService.normalizeDay('09-14'), isNull);
    });
  });

  group('trailingRunOf', () {
    test('counts live run ending today', () {
      final now = DateTime.now();
      final days = List.generate(4, (i) => _day(now.subtract(Duration(days: i))));
      expect(StreakService.trailingRunOf(days, now), 4);
    });

    test('counts live run ending yesterday (today not yet active)', () {
      final now = DateTime.now();
      final days = List.generate(3, (i) => _day(now.subtract(Duration(days: i + 1))));
      expect(StreakService.trailingRunOf(days, now), 3);
    });

    test('dead run with a gap returns 0', () {
      final now = DateTime.now();
      final days = [_day(now.subtract(const Duration(days: 5))), _day(now.subtract(const Duration(days: 3)))];
      expect(StreakService.trailingRunOf(days, now), 0);
    });

    test('empty input returns 0', () {
      expect(StreakService.trailingRunOf(const [], DateTime.now()), 0);
    });
  });

  group('adoptActivityDates', () {
    test('backfills past local journals into the streak', () async {
      SharedPreferences.setMockInitialValues({'streak': 1});
      final now = DateTime.now();
      final days = List.generate(4, (i) => _day(now.subtract(Duration(days: i))));

      final result = await StreakService.adoptActivityDates(days);
      expect(result, 4);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('streak'), 4);
      expect(prefs.getString('last_activity_date'), _day(now));
      final stored = prefs.getStringList('streak_activity_dates') ?? [];
      for (final d in days) {
        expect(stored, contains(d));
      }
    });

    test('never shrinks a healthy streak (max wins)', () async {
      SharedPreferences.setMockInitialValues({'streak': 5});
      final now = DateTime.now();
      final days = List.generate(3, (i) => _day(now.subtract(Duration(days: i))));

      final result = await StreakService.adoptActivityDates(days);
      expect(result, 5);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('streak'), 5);
    });

    test('dead history does not resurrect the streak', () async {
      SharedPreferences.setMockInitialValues({'streak': 1});
      final now = DateTime.now();
      final days = [_day(now.subtract(const Duration(days: 5))), _day(now.subtract(const Duration(days: 4)))];

      final result = await StreakService.adoptActivityDates(days);
      expect(result, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('streak'), 1);
    });

    test('never moves last_activity_date backwards', () async {
      final now = DateTime.now();
      final todayStr = _day(now);
      SharedPreferences.setMockInitialValues({
        'streak': 2,
        'last_activity_date': todayStr,
      });
      final days = [_day(now.subtract(const Duration(days: 3))), _day(now.subtract(const Duration(days: 2)))];

      await StreakService.adoptActivityDates(days);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_activity_date'), todayStr);
    });

    test('ignores garbage input', () async {
      SharedPreferences.setMockInitialValues({'streak': 2});
      final result = await StreakService.adoptActivityDates(const ['', 'nope', '2026-13-99']);
      expect(result, 2);
    });
  });
}
