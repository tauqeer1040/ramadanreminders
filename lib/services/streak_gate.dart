import 'package:flutter/foundation.dart';

import 'local_trial_service.dart';
import 'revenuecat_service.dart';
import 'streak_service.dart';

/// Never-subscribed + display-streak gate.
///
/// Fires the non-dismissable expired sheet when:
/// * no active Max entitlement, AND
/// * never held a subscription (local flag + RC purchase history), AND
/// * friend-boosted display streak (max of local + friend) > [threshold].
///
/// Pure [shouldHardLock] is unit-testable; [shouldShowStreakGate] resolves
/// live state (cached-first, offline-safe).
class StreakGate {
  static const int threshold = 3;

  static bool shouldHardLock({
    required bool subscribed,
    required bool everSubscribed,
    required int displayStreak,
  }) {
    if (subscribed) return false;
    if (everSubscribed) return false;
    return displayStreak > threshold;
  }

  /// Live resolver. Returns false on any error (fail-open: never block
  /// the app on a telemetry failure).
  static Future<bool> shouldShowStreakGate() async {
    try {
      final rc = RevenueCatService.instance;
      final info = rc.cachedCustomerInfo ?? await rc.getCustomerInfo();
      if (rc.hasActiveEntitlement(info)) return false;

      // RC purchase history catches reinstalls where local prefs were wiped.
      final purchased = info?.allPurchasedProductIdentifiers ?? const <String>[];
      if (purchased.isNotEmpty) return false;

      if (await LocalTrialService.hasEverSubscribed()) return false;

      final displayStreak = await StreakService.getDisplayStreak();
      final result = displayStreak > threshold;
      debugPrint(
        '[StreakGate] displayStreak=$displayStreak threshold=$threshold lock=$result',
      );
      return result;
    } catch (e) {
      debugPrint('[StreakGate] resolve failed (fail-open): $e');
      return false;
    }
  }
}
