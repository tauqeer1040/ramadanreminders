import 'package:flutter_test/flutter_test.dart';
import 'package:ramadan_reflections/services/streak_service.dart';

void main() {
  group('longestRunOf', () {
    test('empty history returns 1', () {
      expect(StreakService.longestRunOf([]), 1);
    });

    test('single day returns 1', () {
      expect(StreakService.longestRunOf(['2026-09-10']), 1);
    });

    test('consecutive run returns its length', () {
      expect(
        StreakService.longestRunOf([
          '2026-09-08',
          '2026-09-09',
          '2026-09-10',
          '2026-09-11',
          '2026-09-12',
        ]),
        5,
      );
    });

    test('gap splits runs; longest wins', () {
      expect(
        StreakService.longestRunOf([
          '2026-09-01',
          '2026-09-02',
          '2026-09-05',
          '2026-09-06',
          '2026-09-07',
          '2026-09-08',
          '2026-09-12', // lone today after reset
        ]),
        4,
      );
    });

    test('unordered input still works', () {
      expect(
        StreakService.longestRunOf([
          '2026-09-12',
          '2026-09-08',
          '2026-09-10',
          '2026-09-09',
        ]),
        3,
      );
    });

    test('duplicates and invalid entries are ignored', () {
      expect(
        StreakService.longestRunOf([
          '2026-09-09',
          '2026-09-09',
          'not-a-date',
          '',
          '2026-09-10',
        ]),
        2,
      );
    });
  });
}
