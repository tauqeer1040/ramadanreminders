import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ramadan_reflections/services/trial_service.dart';

void main() {
  group('TrialStatus', () {
    test('fromJson parses server response', () {
      final json = {
        'trialActive': true,
        'daysRemaining': 2,
        'graceMs': 1800000,
        'subscriptionStatus': 'trial',
      };
      final status = TrialStatus.fromJson(json);
      expect(status.trialActive, true);
      expect(status.daysRemaining, 2);
      expect(status.graceMs, 1800000);
      expect(status.subscriptionStatus, 'trial');
      expect(status.canAccess, true);
    });

    test('canAccess is false when trial expired and no grace', () {
      const status = TrialStatus(
        trialActive: false,
        daysRemaining: 0,
        graceMs: 0,
        subscriptionStatus: 'expired',
      );
      expect(status.canAccess, false);
    });

    test('fallback returns valid defaults', () {
      final status = TrialStatus.fallback();
      expect(status.trialActive, true);
      expect(status.daysRemaining, 3);
      expect(status.graceMs, 1800000);
      expect(status.subscriptionStatus, 'none');
      expect(status.canAccess, true);
    });
  });

  group('grace period', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('getRemainingMs returns initial grace when unset', () async {
      final ms = await TrialService.getRemainingMs();
      expect(ms, 30 * 60 * 1000);
    });

    test('deductLaunchCost reduces by 1 minute', () async {
      SharedPreferences.setMockInitialValues({
        'grace_remaining_ms': 30 * 60 * 1000,
      });
      final remaining = await TrialService.deductLaunchCost();
      expect(remaining, 29 * 60 * 1000);
    });

    test('deductLaunchCost does not go below 0', () async {
      SharedPreferences.setMockInitialValues({
        'grace_remaining_ms': 1000,
      });
      final remaining = await TrialService.deductLaunchCost();
      expect(remaining, 0);
    });

    test('hasGraceRemaining returns false when exhausted', () async {
      SharedPreferences.setMockInitialValues({
        'grace_remaining_ms': 0,
      });
      expect(await TrialService.hasGraceRemaining(), false);
    });
  });
}
