import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:ramadan_reflections/services/revenuecat_service.dart';
import 'package:ramadan_reflections/services/streak_gate.dart';

CustomerInfo rcInfoWith({Map<String, dynamic>? activeEntitlement}) {
  final ent = activeEntitlement == null
      ? <String, dynamic>{}
      : {'Meowmin Max': activeEntitlement};
  return CustomerInfo.fromJson({
    'entitlements': {'all': ent, 'active': ent},
    'allPurchaseDates': {},
    'activeSubscriptions': [],
    'allPurchasedProductIdentifiers': [],
    'nonSubscriptionTransactions': [],
    'firstSeen': '2026-01-01T00:00:00Z',
    'originalAppUserId': 'uid-test',
    'originalPurchaseDate': '2026-01-02T00:00:00Z',
    'allExpirationDates': {},
    'requestDate': '2026-01-01T00:00:00Z',
  });
}

Map<String, dynamic> rcEntitlement({
  required String productId,
  required String latestPurchaseDate,
}) {
  return {
    'identifier': 'Meowmin Max',
    'isActive': true,
    'willRenew': true,
    'latestPurchaseDate': latestPurchaseDate,
    'originalPurchaseDate': '2026-01-02T00:00:00Z',
    'productIdentifier': productId,
    'isSandbox': true,
  };
}

void main() {
  group('StreakGate.shouldHardLock', () {
    test('never-subscribed + streak 4 locks', () {
      expect(
        StreakGate.shouldHardLock(
          subscribed: false,
          everSubscribed: false,
          displayStreak: 4,
        ),
        isTrue,
      );
    });

    test('never-subscribed + streak 3 does not lock (strict >3)', () {
      expect(
        StreakGate.shouldHardLock(
          subscribed: false,
          everSubscribed: false,
          displayStreak: 3,
        ),
        isFalse,
      );
    });

    test('subscribed never locks', () {
      expect(
        StreakGate.shouldHardLock(
          subscribed: true,
          everSubscribed: true,
          displayStreak: 30,
        ),
        isFalse,
      );
    });

    test('lapsed (ever-subscribed) never locks via this gate', () {
      expect(
        StreakGate.shouldHardLock(
          subscribed: false,
          everSubscribed: true,
          displayStreak: 30,
        ),
        isFalse,
      );
    });
  });

  group('RevenueCatService.welcomeKeyFor', () {
    test('key carries product + latest purchase date', () {
      final key = RevenueCatService.welcomeKeyFor(
        rcInfoWith(
          activeEntitlement: rcEntitlement(
            productId: 'monthly-1',
            latestPurchaseDate: '2026-02-01T00:00:00Z',
          ),
        ),
      );
      expect(key, 'monthly-1@2026-02-01T00:00:00Z');
    });

    test('renewal produces a NEW key (thank-you shows again)', () {
      final before = RevenueCatService.welcomeKeyFor(
        rcInfoWith(
          activeEntitlement: rcEntitlement(
            productId: 'monthly-1',
            latestPurchaseDate: '2026-02-01T00:00:00Z',
          ),
        ),
      );
      final after = RevenueCatService.welcomeKeyFor(
        rcInfoWith(
          activeEntitlement: rcEntitlement(
            productId: 'monthly-1',
            latestPurchaseDate: '2026-03-01T00:00:00Z',
          ),
        ),
      );
      expect(after, isNot(equals(before)));
    });

    test('no entitlement falls back to account date, null to timestamp', () {
      final fallback =
          RevenueCatService.welcomeKeyFor(rcInfoWith());
      expect(fallback, '2026-01-02T00:00:00Z');
      expect(RevenueCatService.welcomeKeyFor(null), startsWith('ts:'));
    });
  });
}
