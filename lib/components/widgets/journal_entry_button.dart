import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../../theme/app_theme.dart';
import 'duo_button.dart';
import '../journal_bottom_sheet.dart';
import 'max_welcome_sheet.dart';
import '../../services/star_service.dart';
import '../../services/entitlement_service.dart';
import '../../services/local_trial_service.dart';
import '../../services/revenuecat_service.dart';

class JournalEntryButton extends StatefulWidget {
  final String displayName;
  final GlobalKey starBadgeKey;
  final ValueChanged<String?>? onJournalSaved;
  final ValueChanged<int>? onStarsTicked;

  const JournalEntryButton({
    super.key,
    required this.displayName,
    required this.starBadgeKey,
    this.onJournalSaved,
    this.onStarsTicked,
  });

  @override
  State<JournalEntryButton> createState() => JournalEntryButtonState();
}

class JournalEntryButtonState extends State<JournalEntryButton> {
  final _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  String? _mascotMessage;

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  String? get lastMascotMessage => _mascotMessage;

  /// Waits for the sheet-pop + keyboard-dismiss transition to settle so
  /// the celebration setStates never fight a mid-transition reflow (the
  /// "button teleports" glitch). Bounded: proceeds after 650ms regardless.
  Future<void> _waitForLayoutSettled() async {
    var waited = 0;
    while (mounted && waited < 500) {
      double bottom = 0;
      try {
        bottom = MediaQuery.of(context).viewInsets.bottom;
      } catch (_) {}
      if (bottom <= 0) break;
      await Future.delayed(const Duration(milliseconds: 50));
      waited += 50;
    }
    await Future.delayed(const Duration(milliseconds: 150));
  }

  Future<void> _onJournalSaved(double moodValue) async {
    HapticFeedback.mediumImpact();
    await _waitForLayoutSettled();
    if (!mounted) return;

    // Awards (no trail): first finish of the day pays +10, plus a one-time
    // +50 on the very first journal ever. Later saves pay nothing.
    final awardToday = await StarService.claimDailyJournalAward();
    final firstEver = await StarService.claimFirstJournalBonus();
    if (firstEver) {
      // Record server-side (idempotent one-timer). Response ignored on
      // purpose: server doesn't track the local-only awards, so its total
      // must never overwrite the local balance here.
      StarService.notifyFirstJournalBonus();
    }
    if (awardToday || firstEver) {
      final amount = (awardToday ? 10 : 0) + (firstEver ? 50 : 0);
      await StarService.addStars(amount);
      if (mounted) widget.onStarsTicked?.call(amount);
    }

    // Celebration on every save.
    _confettiController.play();

    if (mounted) {
      const templates = [
        "Diary saved! Come back tomorrow morning to read your AI insights, {name}.",
        "Diary saved! I'll start making your Personal AI insights, {name}!",
        "Diary saved! Your entry is safe with me. I'll prepare your AI insights for tomorrow morning, {name}.",
        "Diary saved! Beautiful reflection, {name}! Check back tomorrow morning for your AI insights.",
        "Diary saved! Time to analyze your mood and write down some sweet insights for you tomorrow morning, {name}."
      ];
      final msg = templates[Random().nextInt(templates.length)].replaceAll('{name}', widget.displayName);
      setState(() => _mascotMessage = msg);
      widget.onJournalSaved?.call(msg);
    }
  }

  Future<void> showEditor(BuildContext context) async {
    if (!context.mounted) return;

    // Hard paywall: past-grace non-subscribers must go through Max before
    // the editor opens. Uses the soft window (trial active OR lapsed-subscriber
    // grace) so paid users who churned keep their dismissable 3 days, and
    // server-denied devices are honoured. Fail-open on errors (never trap
    // the editor on a bug — splash/resume gates still cover the app).
    try {
      final subscribed =
          await RevenueCatService.instance.isSubscribed();
      final pastGrace =
          await LocalTrialService.isPastGrace();
      // Server verdict overrides the local clock: an expired trial must not
      // be able to keep journaling by resetting local state.
      final serverLocked = subscribed
          ? false
          : await EntitlementService.shouldLock(subscribed: false);
      if (!subscribed && (pastGrace || serverLocked) && context.mounted) {
        final result = await RevenueCatService.instance.presentPaywall(
          displayCloseButton: false,
        );
        if (result == PaywallResult.purchased ||
            result == PaywallResult.restored) {
          try {
            await RevenueCatService.instance.getCustomerInfo();
          } catch (_) {}
          await RevenueCatService.flagWelcomePending(
            forceShow: result == PaywallResult.restored,
          );
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Max is needed to keep journaling ✍️'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
    } catch (_) {}

    if (!context.mounted) return;
    final wroteResult = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => JournalBottomSheet(scrollController: scrollCtrl),
      ),
    );
    if (wroteResult is double) {
      await _onJournalSaved(wroteResult);
    }
    // Thank-you sheet for purchases completed through the Write gate.
    try {
      if (context.mounted) {
        await MaxWelcomeSheet.showIfPending(context);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DuoButton(
          onPressed: () => showEditor(context),
          backgroundColor: AppTheme.neonPurple,
          depthColor: AppTheme.neonPurple.withValues(alpha: 0.7),
          radius: 20,
          height: 72,
          sfxType: DuoSfxType.positive,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_rounded, color: AppTheme.starWhite, size: 22),
              const SizedBox(width: 10),
              Text(
                'Write',
                style: TextStyle(
                  color: AppTheme.starWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        IgnorePointer(
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 8,
            emissionFrequency: 0.02,
            maxBlastForce: 35,
            minBlastForce: 10,
            colors: const [
              Colors.blue, Colors.pink, Colors.yellow, Colors.green,
            ],
          ),
        ),
      ],
    );
  }
}
