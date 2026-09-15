import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:ramadan_reflections/services/max_status.dart';

CustomerInfo infoWith({Map<String, dynamic>? activeEntitlement}) {
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
    'allExpirationDates': {},
    'requestDate': '2026-01-01T00:00:00Z',
  });
}

Map<String, dynamic> entitlement({
  required String productId,
  String? expiresIn,
}) {
  final now = DateTime.now().toUtc();
  final expiry = expiresIn == null
      ? null
      : now.add(Duration(days: int.parse(expiresIn))).toIso8601String();
  return {
    'identifier': 'Meowmin Max',
    'isActive': true,
    'willRenew': true,
    'latestPurchaseDate': now.toIso8601String(),
    'originalPurchaseDate': now.toIso8601String(),
    'productIdentifier': productId,
    'isSandbox': true,
    'expirationDate': expiry,
  };
}

void main() {
  group('MaxStatus.fromCustomerInfo', () {
    test('no entitlement -> inactive (upsells shown)', () {
      final s = MaxStatusService.fromCustomerInfo(infoWith());
      expect(s.state, MaxState.inactive);
      expect(s.showUpsells, isTrue);
      expect(s.showExpiryBanner, isFalse);
    });

    test('null info -> inactive', () {
      final s = MaxStatusService.fromCustomerInfo(null);
      expect(s.state, MaxState.inactive);
    });

    test('active monthly far from expiry -> active, no upsells, no banner', () {
      final s = MaxStatusService.fromCustomerInfo(
        infoWith(activeEntitlement: entitlement(productId: 'monthly-1', expiresIn: '20')),
      );
      expect(s.state, MaxState.active);
      expect(s.showUpsells, isFalse);
      expect(s.showExpiryBanner, isFalse);
    });

    test('expiring in 2 days -> expiringSoon with countdown', () {
      final s = MaxStatusService.fromCustomerInfo(
        infoWith(activeEntitlement: entitlement(productId: 'monthly-1', expiresIn: '2')),
      );
      expect(s.state, MaxState.expiringSoon);
      expect(s.daysRemaining, 2);
      expect(s.showExpiryBanner, isTrue);
      expect(s.showUpsells, isFalse);
    });

    test('expiring in hours -> 1 day countdown, not zero', () {
      final now = DateTime.now().toUtc();
      final s = MaxStatusService.fromCustomerInfo(infoWith(
        activeEntitlement: {
          ...entitlement(productId: 'weekly-1'),
          'expirationDate': now.add(const Duration(hours: 5)).toIso8601String(),
        },
      ));
      expect(s.state, MaxState.expiringSoon);
      expect(s.daysRemaining, 1);
    });

    test('lifetime -> active forever, never expiring', () {
      final s = MaxStatusService.fromCustomerInfo(
        infoWith(activeEntitlement: entitlement(productId: 'lifetime-gift')),
      );
      expect(s.state, MaxState.active);
      expect(s.lifetime, isTrue);
      expect(s.showExpiryBanner, isFalse);
    });

    test('Play 4-month plan is labelled 4-month, not 30-day', () {
      // Play versionName of the plan is `meowmin_4month`.
      expect(MaxStatusService.planLabelFor('meowmin_4month'), '4-month challenge');
      expect(MaxStatusService.planLabelFor('four-month-journey'), '4-month challenge');
      expect(MaxStatusService.planLabelFor('meowmin_yearly'), '12-month journey');
      expect(MaxStatusService.planLabelFor('meowmin_monthly'), '30-day challenge');
      expect(MaxStatusService.planLabelFor('meowmin_lifetime'), 'Lifetime');
    });

    test('cancelled-but-active (willRenew false, future expiry) still counts down', () {
      final s = MaxStatusService.fromCustomerInfo(infoWith(
        activeEntitlement: {
          ...entitlement(productId: 'monthly-1', expiresIn: '1'),
          'willRenew': false,
          'unsubscribeDetectedAt': DateTime.now().toUtc().toIso8601String(),
        },
      ));
      expect(s.state, MaxState.expiringSoon);
      expect(s.showExpiryBanner, isTrue);
    });
  });
}
