import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import '../../theme/app_theme.dart';
import '../widgets/duo_button.dart';
import '../widgets/duo_progress_bar.dart';
import 'onboarding_data.dart';

// ── Paywall Step 1 ─────────────────────────────────────────────────────────
// "I'm Ahmed — the person who built Meowmin."

class PaywallPage1 extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const PaywallPage1({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  State<PaywallPage1> createState() => _PaywallPage1State();
}

class _PaywallPage1State extends State<PaywallPage1> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _generateSlot();
  }

  Future<void> _generateSlot() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('paywall_view_count') ?? 0;

    int min, max;
    if (count == 0) {
      min = 160; max = 180;
    } else if (count == 1) {
      min = 180; max = 200;
    } else {
      min = 200; max = 220;
    }

    final rng = Random();
    final number = min + rng.nextInt(max - min + 1);
    await prefs.setInt('paywall_slot_number', number);
    await prefs.setInt('paywall_view_count', count + 1);

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = widget.data.displayName;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 32),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 24),
                    Text(
                      "A word from the guy who made Meowmin...",
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Hi $name,",
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "I'm Ahmed, the person who built Meowmin. Not a company. Not a venture-backed team.\nJust me.\n\nFor months, I worked on this app obsessively \ndesigning it, coding it, fixing the tiny details\nmost people never notice.",
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: DuoButton(
                            onPressed: widget.onBack,
                            backgroundColor: cs.secondaryContainer,
                            depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                            radius: 16,
                            height: 56,
                            sfxType: DuoSfxType.negative,
                            child: Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 16,
                                color: cs.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: DuoButton(
                            onPressed: _ready ? widget.onNext : null,
                            backgroundColor: cs.primary,
                            depthColor: cs.primary.withValues(alpha: 0.8),
                            radius: 16,
                            height: 56,
                            sfxType: DuoSfxType.positive,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                  color: cs.onSurface,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Paywall Step 2 ─────────────────────────────────────────────────────────
// "Software isn't free."

class PaywallPage2 extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const PaywallPage2({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  State<PaywallPage2> createState() => _PaywallPage2State();
}

class _PaywallPage2State extends State<PaywallPage2> {
  int _slotNumber = 0;

  @override
  void initState() {
    super.initState();
    _loadSlot();
  }

  Future<void> _loadSlot() async {
    final prefs = await SharedPreferences.getInstance();
    final number = prefs.getInt('paywall_slot_number') ?? 183;
    if (mounted) setState(() => _slotNumber = number);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = widget.data.displayName ?? 'friend';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 32),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Software isn't free",
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                       "Meowmin isn't free to use.\nBut free software is never truly free.\nAI costs money. Servers cost money.\nTime costs money.\n\nSo I made a choice.\n\nI don't sell your data.\nI don't run ads.\nI don't treat users like inventory.\n\nInstead, Meowmin survives because\na small group of people decide\nit's worth supporting.\n\nMembership is intentionally limited to\n300 total members. Today, you'd be\nmember #$_slotNumber, $name",
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    if (_slotNumber > 0) ...[
                      Text(
                        "Limited to 300 members",
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DuoProgressBar(
                        progress: _slotNumber / 300,
                        height: 14,
                        radius: 10,
                        fillColor: AppTheme.starGold,
                      ),
                      const SizedBox(height: 12),
                      Shimmer.fromColors(
                        baseColor: AppTheme.starGold.withValues(alpha: 0.7),
                        highlightColor: AppTheme.starGold,
                        period: const Duration(milliseconds: 2000),
                        child: Text(
                          "$_slotNumber of 300 slots filled",
                          style: tt.labelSmall?.copyWith(
                            color: AppTheme.starWhite,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: DuoButton(
                            onPressed: widget.onBack,
                            backgroundColor: cs.secondaryContainer,
                            depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                            radius: 16,
                            height: 56,
                            sfxType: DuoSfxType.negative,
                            child: Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 16,
                                color: cs.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: DuoButton(
                            onPressed: widget.onNext,
                            backgroundColor: cs.primary,
                            depthColor: cs.primary.withValues(alpha: 0.8),
                            radius: 16,
                            height: 56,
                            sfxType: DuoSfxType.positive,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                  color: cs.onSurface,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Paywall Step 3 ─────────────────────────────────────────────────────────
// Pricing + Superwall paywall CTA

class PaywallPage3 extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;

  const PaywallPage3({
    required this.data,
    required this.onNext,
    super.key,
  });

  @override
  State<PaywallPage3> createState() => _PaywallPage3State();
}

class _PaywallPage3State extends State<PaywallPage3> {
  void _showPaywall() {
    HapticFeedback.mediumImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Superwall.shared.identify(user.uid);
      }
    } catch (_) {}

    Superwall.shared.registerPlacement('campaign_trigger', feature: () {
      if (mounted) widget.onNext();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 32),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Keep Meowmin independent",
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "For less than the price of a coffee, you can spend the next three days putting Meowmin to a real test. Journal each morning and night. Let the reflections surface. See if the Quran begins to read you as much as you read it.\n\nIf, after three days, you don't feel this was the best dollar you've ever spent on your aakhirah, we'll refund it. No questions asked.",
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.starGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '\$1',
                          style: TextStyle(
                            color: AppTheme.starGold,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '3-Day Trial',
                              style: TextStyle(
                                color: AppTheme.starWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Then \$59/yr or \$9/mo',
                              style: TextStyle(
                                color: AppTheme.ghostSilver.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: DuoButton(
                      onPressed: _showPaywall,
                      backgroundColor: AppTheme.starGold,
                      depthColor: AppTheme.starGold.withValues(alpha: 0.6),
                      radius: 16,
                      height: 56,
                      child: const Text(
                        'Start Your \$1 Trial',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: widget.onNext,
                    child: Text(
                      "Skip — I'll do this later",
                      style: TextStyle(
                        color: AppTheme.ghostSilver.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ],
          ),
        ));
      },
    );
  }
}
