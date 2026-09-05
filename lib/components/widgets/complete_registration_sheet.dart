import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_background.dart';
import '../../services/analytics_service.dart';
import '../../services/email_continue_service.dart';
import '../../services/revenuecat_service.dart';
import '../../theme/app_theme.dart';
import '../onboarding/check_email_page.dart';
import '../onboarding/onboarding_data.dart';
import '../onboarding/pages/email_page.dart';
import 'duo_button.dart';
import 'glass_container.dart';

/// "Confirm registration": opens onboarding step 19 as a standalone route
/// while simultaneously minting a continue-token so the Resend registration
/// email goes out instantly. Fire-and-forget mint — failures never block.
Future<void> openConfirmRegistration(BuildContext context) async {
  HapticFeedback.mediumImpact();
  String email = FirebaseAuth.instance.currentUser?.email ?? '';
  if (email.isEmpty) {
    try {
      final prefs = await SharedPreferences.getInstance();
      email = prefs.getString('onboarding_email') ?? '';
    } catch (_) {}
  }
  try {
    AnalyticsService.instance.logEvent('confirm_registration_opened');
  } catch (_) {}
  if (email.isNotEmpty) {
    EmailContinueService.mint(email: email).then((res) {
      debugPrint(
        '[Registration] background mint: emailed=${res?['emailed']}',
      );
    }).catchError((_) {});
  }
  if (!context.mounted) return;
  final data = OnboardingData()..email = email.isNotEmpty ? email : null;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        body: AppBackground(
          backgroundImage: 'assets/photos/elements/onboarding.webp',
          overlayOpacity: 0.35,
          child: SafeArea(
            child: EmailPage(
              data: data,
              onNext: () => Navigator.of(context).pop(),
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Email-only membership entry. Collects the user's email, then opens the
/// existing [CheckEmailScreen] (soft mode: skippable, unlocks automatically
/// on purchase). No prices, no store billing, no external checkout links —
/// companion-safe for Google Play.
Future<void> showCompleteRegistrationSheet(BuildContext context) async {
  HapticFeedback.lightImpact();
  try {
    AnalyticsService.instance.logEvent('registration_sheet_shown');
  } catch (_) {}
  await showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: GlassContainer(
        sigmaX: 20,
        sigmaY: 20,
        tint: Colors.white.withValues(alpha: 0.05),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
        child: const _RegistrationForm(),
      ),
    ),
  );
}

class _RegistrationForm extends StatefulWidget {
  const _RegistrationForm();

  @override
  State<_RegistrationForm> createState() => _RegistrationFormState();
}

class _RegistrationFormState extends State<_RegistrationForm> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid {
    final v = _controller.text.trim();
    return v.contains('@') && v.contains('.');
  }

  void _continue() {
    final email = _controller.text.trim();
    if (!_valid) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    try {
      AnalyticsService.instance.logEvent('registration_email_submitted');
    } catch (_) {}
    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: CheckEmailScreen(
                email: email,
                onSkip: () => Navigator.of(context).pop(),
                onUnlocked: () async {
                  Navigator.of(context).pop();
                  try {
                    final info = await RevenueCatService.instance
                        .restorePurchases();
                    final ok = RevenueCatService.instance
                        .hasActiveEntitlement(info);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'Welcome to Meowmin Max!'
                              : 'Email confirmed — Max unlocks after checkout.'),
                        ),
                      );
                    }
                  } catch (_) {}
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Complete registration',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add your email to secure your journals and unlock your member space.',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _continue(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: TextStyle(color: cs.onSurface, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'you@example.com',
                hintStyle: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
                errorText: _error,
                filled: true,
                fillColor: cs.onSurface.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            DuoButton(
              onPressed: _continue,
              backgroundColor: AppTheme.starGold,
              depthColor: const Color(0xFFD4A20C),
              radius: 16,
              height: 56,
              sfxType: DuoSfxType.positive,
              child: const Text(
                'Continue',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Maybe later',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
