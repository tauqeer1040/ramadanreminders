import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/widgets/max_welcome_sheet.dart';
import 'local_trial_service.dart';
import 'revenuecat_service.dart';

/// Fires the RevenueCat paywall sheet directly (no intermediate gate screen)
/// at conversion moments (journal saved, deck revealed) for free users.
/// Dismissable (close button) while the 3-day trial is active; a hard
/// sheet (no close button) afterwards. Frequency-capped per moment so it
/// never nags more than once per window.
class MomentPaywallService {
  static const Duration _minGap = Duration(minutes: 30);
  static const String _lastShownKey = 'moment_paywall_last_';

  /// Delay after a full deck reveal before presenting, so the user gets to
  /// enjoy the reveal moment first. Presented even if they navigate away
  /// before the delay elapses (the sheet needs no BuildContext).
  static const Duration _deckRevealDelay = Duration(seconds: 10);

  static Future<void> maybeShow(
    BuildContext context, {
    required String moment,
  }) =>
      maybeShowOnNavigator(
        Navigator.of(context, rootNavigator: true),
        moment: moment,
      );

  /// Navigator-based entry kept for caller compatibility (the editor's
  /// context is dead by call time). The navigator itself is no longer
  /// needed — the RevenueCat sheet presents without a context.
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

      if (moment == 'deck_revealed') {
        await Future.delayed(_deckRevealDelay);
        // Re-check: they may have subscribed during the delay.
        if (await RevenueCatService.instance.isSubscribed()) return;
      }

      final dismissable = await LocalTrialService.isSoftWindow();
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null && uid.isNotEmpty) {
          await RevenueCatService.instance.identify(uid);
        }
      } catch (_) {}
      // Stamp the resume cooldown so an aha paywall doesn't get followed by
      // a resume paywall seconds later.
      await LocalTrialService.notePaywallShown();
      LocalTrialService.sheetOpen = true;
      PaywallResult result;
      try {
        result = await RevenueCatService.instance.presentPaywall(
          displayCloseButton: dismissable,
        );
      } finally {
        LocalTrialService.sheetOpen = false;
        LocalTrialService.lastSheetClosed = DateTime.now();
      }
      if (result == PaywallResult.purchased ||
          result == PaywallResult.restored) {
        // Pull fresh customer info so entitlement reads update instantly
        // (the SDK update listener also pushes — this is belt-and-braces).
        await RevenueCatService.instance.getCustomerInfo();
        await RevenueCatService.flagWelcomePending(
          forceShow: result == PaywallResult.restored,
        );
        try {
          if (navigator.mounted) {
            await MaxWelcomeSheet.showIfPending(navigator.context);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }
}
