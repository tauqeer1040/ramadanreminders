import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import '../onboarding_data.dart';
import '../../widgets/duo_button.dart';
import '../../../theme/app_theme.dart';
import '../../../services/revenuecat_service.dart';
import '../../../services/local_trial_service.dart';

/// Step 15: Qualifying mark — the user has earned member pricing after their
/// first reflection. Framed as an achievement (loss aversion) with a
/// refundable $1 offer tied to a 30-day journal challenge.
class QualifyingPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const QualifyingPage({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  State<QualifyingPage> createState() => _QualifyingPageState();
}

class _QualifyingPageState extends State<QualifyingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fireConfetti();
    });
  }

  void _fireConfetti() {
    final cs = Theme.of(context).colorScheme;
    Confetti.launch(
      context,
      options: ConfettiOptions(
        particleCount: 60,
        spread: 70,
        y: 0.6,
        colors: [
          cs.primary,
          AppTheme.starGold,
          const Color(0xFFF4A6B8),
          const Color(0xFF81D4FA),
        ],
      ),
    );
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
                    Text(
                      '🌟',
                      style: const TextStyle(fontSize: 56),
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                        children: [
                          const TextSpan(text: "You've qualified"),
                          if (name != null)
                            TextSpan(
                              text: ",\n$name",
                              style: const TextStyle(
                                color: AppTheme.starGold,
                              ),
                            ),
                          const TextSpan(text: "!"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "After your first reflection, you've unlocked member pricing.",
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    // Pricing card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.starGold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.starGold.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '\$1',
                                style: TextStyle(
                                  color: AppTheme.starGold,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  ' for 30 days',
                                  style: tt.titleMedium?.copyWith(
                                    color: cs.onSurface.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.replay_rounded,
                                  size: 16,
                                  color: Color(0xFF4CAF50),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    "Fully refunded if you complete the 30-day journal challenge",
                                    style: tt.labelMedium?.copyWith(
                                      color: const Color(0xFF4CAF50),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "That's 30 personalized Quran insights, 30 streaks, and 30 days of growing closer to Allah.\nIf you finish, you pay nothing.",
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: DuoButton(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          final result = await RevenueCatService.instance.presentPaywall(
                            displayCloseButton: true,
                          );
                          if (result == PaywallResult.purchased || result == PaywallResult.restored) {
                            widget.onNext();
                          }
                        },
                        backgroundColor: AppTheme.starGold,
                        depthColor: AppTheme.starGold.withValues(alpha: 0.6),
                        radius: 16,
                        height: 56,
                        child: const Text(
                          'Claim your spot',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        await LocalTrialService.startTrial();
                        widget.onNext();
                      },
                      child: Text(
                        "Skip — I'll do this later",
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.45),
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
          ),
        );
      },
    );
  }
}
