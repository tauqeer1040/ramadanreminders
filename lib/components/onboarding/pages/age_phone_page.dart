import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding_data.dart';
import '../../../services/analytics_service.dart';
import '../../widgets/duo_button.dart';
import '../../widgets/commitment_button.dart';
import '../../../theme/app_theme.dart';

// ── Step 3: Intention ("Are you ready for deep reflection?") ──────────────
class IntentionPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final void Function(int) onGoToStep;

  const IntentionPage({
    required this.data,
    required this.onNext,
    required this.onBack,
    required this.onGoToStep,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final catName = data.catName;
    final userName = data.displayName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        key: const ValueKey('intention_step'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          Text(
            "Are you ready for a deep reflection${userName != null ? ", $userName" : ""}?",
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "A moment of honest clarity can sometimes bring the most beautiful insights. Are you ready for a hard question${userName != null ? ", $userName" : ""}?",
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          DuoButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              AnalyticsService.instance.logEvent('onboarding_hard_questions_chosen', params: {'chosen': 'true'});
              data.chosenHard = true;
              onNext();
            },
            backgroundColor: cs.primary,
            depthColor: cs.primary.withValues(alpha: 0.8),
            radius: 16,
            height: 56,
            sfxType: DuoSfxType.positive,
            child: Text(
              "I'm ready${catName != null ? ", $catName" : ""}",
              style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          DuoButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              AnalyticsService.instance.logEvent('onboarding_hard_questions_chosen', params: {'chosen': 'false'});
              data.chosenHard = false;
              // Skip MillionDollars, Wakeup, Conclusion → go straight to PhoneHours (step 7)
              onGoToStep(7);
            },
            backgroundColor: cs.secondaryContainer,
            depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
            radius: 16,
            height: 56,
            sfxType: DuoSfxType.negative,
            child: Text(
              "No hard questions today, please",
              style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(flex: 1),
          Row(
            children: [
              Expanded(
                child: DuoButton(
                  onPressed: onBack,
                  backgroundColor: cs.secondaryContainer,
                  depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                  radius: 16,
                  sfxType: DuoSfxType.negative,
                  child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ── Step 4: Million Dollars ("Would you take 10 million?") ──────────────
class MillionDollarsPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const MillionDollarsPage({required this.onNext, required this.onBack, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        key: const ValueKey('million_dollars_step'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          Image.asset('assets/photos/elements/money-bag_1f4b0.webp', height: 120, fit: BoxFit.contain),
          const SizedBox(height: 24),
          Text("First, take a gentle breath and imagine...", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text("If someone offered you 10 million dollars right now, would you take it?", style: tt.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.8), height: 1.6), textAlign: TextAlign.center),
          const Spacer(flex: 1),
          Row(
            children: [
              Expanded(flex: 1, child: DuoButton(onPressed: onBack, backgroundColor: cs.secondaryContainer, depthColor: cs.secondaryContainer.withValues(alpha: 0.8), radius: 16, sfxType: DuoSfxType.negative, child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)))),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: DuoButton(onPressed: () { HapticFeedback.lightImpact(); AnalyticsService.instance.logEvent('onboarding_million_dollars'); onNext(); }, backgroundColor: cs.primary, depthColor: cs.primary.withValues(alpha: 0.8), radius: 16, sfxType: DuoSfxType.positive, child: Text("Yeah!", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)))),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ── Step 5: Wake Up ("You don't get to wake up tomorrow") ──────────────
class WakeupPage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const WakeupPage({required this.onNext, required this.onBack, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        key: const ValueKey('wakeup_step'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          Image.asset('assets/photos/elements/hourglass-done_231b.webp', height: 120, fit: BoxFit.contain),
          const SizedBox(height: 24),
          Text("There's one catch though...", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text("You don't get to wake up tomorrow morning. Your time here ends tonight. The 10 million is yours \u2014 but so is that.\n\nWould you still take it?", style: tt.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.8), height: 1.6), textAlign: TextAlign.center),
          const Spacer(flex: 1),
          Row(
            children: [
              Expanded(flex: 1, child: DuoButton(onPressed: onBack, backgroundColor: cs.secondaryContainer, depthColor: cs.secondaryContainer.withValues(alpha: 0.8), radius: 16, sfxType: DuoSfxType.negative, child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)))),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: DuoButton(onPressed: () { HapticFeedback.lightImpact(); AnalyticsService.instance.logEvent('onboarding_wakeup_choice'); onNext(); }, backgroundColor: cs.primary, depthColor: cs.primary.withValues(alpha: 0.8), radius: 16, sfxType: DuoSfxType.positive, child: Text("Nah!", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)))),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ── Step 6: Conclusion ("Exactly!" + fingerprint) ──────────────────────
class ConclusionPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const ConclusionPage({required this.data, required this.onNext, required this.onBack, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = data.displayName ?? 'friend';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        key: const ValueKey('conclusion_step'),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Text("Exactly!", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text('Your 30-day challenge\nstarts tonight, $name.', style: tt.headlineSmall?.copyWith(color: AppTheme.starGold, fontWeight: FontWeight.bold, height: 1.3), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🛏️', style: TextStyle(fontSize: 72)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, size: 20)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Image.asset('assets/photos/mascot/face.webp', width: 72, height: 72)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, size: 20)),
              const Text('💤', style: TextStyle(fontSize: 72)),
            ],
          ),
          const SizedBox(height: 20),
          _bulletRow('Every night before sleep, open Meowmin and write one thought.', tt, cs),
          const SizedBox(height: 8),
          _bulletRow('30 nights. 30 thoughts.', tt, cs),
          const SizedBox(height: 8),
          _bulletRow('By the end, you won\'t just have a journal \u2014 you\'ll have a habit that brings you closer to Allah.', tt, cs),
          const SizedBox(height: 32),
          Center(
            child: CommitmentButton(
              onCommit: () {
                HapticFeedback.mediumImpact();
                AnalyticsService.instance.logEvent('onboarding_commitment_made');
                onNext();
              },
              color: AppTheme.starGold,
              size: 144,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text("Most people talk about changing.\nYou're about to do it.", style: tt.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.6), fontStyle: FontStyle.italic), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Take the challenge', style: tt.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          Row(children: [Expanded(child: DuoButton(onPressed: onBack, backgroundColor: cs.secondaryContainer, depthColor: cs.secondaryContainer.withValues(alpha: 0.8), radius: 16, sfxType: DuoSfxType.negative, child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold))))]),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _bulletRow(String text, TextTheme tt, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: Text(text, style: tt.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.8))))]),
    );
  }
}

// ── Step 7: Phone Hours ("How many hours on phone?") ───────────────────
class PhoneHoursPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const PhoneHoursPage({required this.data, required this.onNext, required this.onBack, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    double phoneHours = (data.phoneHours ?? 4).toDouble();

    return StatefulBuilder(
      builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            key: const ValueKey('phone_hours_step'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 1),
              Text("How many hours do you spend on your phone daily${data.displayName != null ? " ${data.displayName}" : ""}?", style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text("${phoneHours.toInt()} hrs/day", style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 8),
              Slider(value: phoneHours, min: 0, max: 16, divisions: 16, onChanged: (v) => setState(() => phoneHours = v)),
              const Spacer(flex: 1),
              Row(
                children: [
                  Expanded(flex: 1, child: DuoButton(onPressed: onBack, backgroundColor: cs.secondaryContainer, depthColor: cs.secondaryContainer.withValues(alpha: 0.8), radius: 16, height: 56, sfxType: DuoSfxType.negative, child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)))),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: DuoButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      data.phoneHours = phoneHours.toInt();
                      AnalyticsService.instance.logEvent('onboarding_phone_hours', params: {'hours': phoneHours.toInt().toString()});
                      onNext();
                    },
                    backgroundColor: cs.primary, depthColor: cs.primary.withValues(alpha: 0.8), radius: 16, height: 56, sfxType: DuoSfxType.positive,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Continue", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)), const SizedBox(width: 8), Icon(Icons.arrow_forward_rounded, size: 20, color: cs.onSurface)]),
                  )),
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }
}
