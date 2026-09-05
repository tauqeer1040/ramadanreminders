import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../check_email_page.dart';
import '../onboarding_data.dart';
import '../../widgets/duo_button.dart';
import '../../../services/analytics_service.dart';

/// Step 19: "check your email to complete registration". The address comes
/// from the mandatory Google sign-in (step 18); the screen mints a
/// continue-token on show so the delight email (Resend) goes out instantly.
/// Skip for now stays — trial first, email whenever.
class EmailPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const EmailPage({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  Map<String, dynamic> _snapshot() {
    final journal = data.journalEntry;
    final mins = DateTime.now().difference(data.startTime).inMinutes;
    return {
      'intention': data.intentionAnswer,
      'journalExcerpt': journal == null
          ? null
          : (journal.length > 500 ? journal.substring(0, 500) : journal),
      'insights': data.journalAnalogies.take(3).toList(),
      'timeSpent': mins < 1 ? 'a few mindful minutes' : '${mins}m',
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final email = FirebaseAuth.instance.currentUser?.email ??
        (data.email ?? '').trim();
    try {
      AnalyticsService.instance.logEvent('onboarding_email_step_shown');
    } catch (_) {}
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: CheckEmailScreen(
              email: email,
              snapshot: _snapshot(),
              title: 'Check your email to complete registration',
              skipLabel: 'Skip for now',
              onSkip: onNext,
              onUnlocked: onNext,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
          child: Row(
            children: [
              Expanded(
                child: DuoButton(
                  onPressed: onBack,
                  backgroundColor: cs.secondaryContainer,
                  depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                  radius: 16,
                  height: 56,
                  sfxType: DuoSfxType.negative,
                  child: Text(
                    "Back",
                    style: TextStyle(
                      fontSize: 16,
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
