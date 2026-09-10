import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/paywall_gate_screen.dart';
import 'local_trial_service.dart';
import 'revenuecat_service.dart';

/// Fires the paywall at conversion moments (journal saved, deck revealed)
/// for free users. Dismissable while the 3-day trial is active; a hard
/// non-dismissable gate afterwards. Frequency-capped per moment so it
/// never nags more than once per window.
class MomentPaywallService {
  static const Duration _minGap = Duration(minutes: 30);
  static const String _lastShownKey = 'moment_paywall_last_';

  static Future<void> maybeShow(
    BuildContext context, {
    required String moment,
  }) =>
      maybeShowOnNavigator(
        Navigator.of(context, rootNavigator: true),
        moment: moment,
      );

  /// Navigator-based entry so callers can trigger AFTER popping their own
  /// route (the editor's context is dead by then).
  static Future<void> maybeShowOnNavigator(
    NavigatorState navigator, {
    required String moment,
  }) async {
    try {
      if (await RevenueCatService.instance.isSubscribed()) return;
      if (!await LocalTrialService.hasStarted()) return;

      final prefs = await SharedPreferences.getInstance();
      final key = '$_lastShownKey$moment';
      final last = prefs.getInt(key) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < _minGap.inMilliseconds) return;
      await prefs.setInt(key, now);

      final dismissable = await LocalTrialService.isActive();
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => PaywallGateScreen(
            isDismissable: dismissable,
            onSubscribe: () => navigator.pop(),
            onDismiss: () => navigator.pop(),
          ),
        ),
      );
    } catch (_) {}
  }
}
