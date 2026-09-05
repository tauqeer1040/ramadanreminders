import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/onboarding/check_email_page.dart';
import '../core/app_background.dart';
import '../services/analytics_service.dart';
import 'main_screen.dart';

/// Shown on every launch until the user subscribes to Max: the same
/// check-email screen as onboarding step 19. Soft while the trial runs
/// (Skip → home), hard after expiry (no skip — use PaywallGateScreen).
class EmailGateScreen extends StatefulWidget {
  const EmailGateScreen({super.key});

  @override
  State<EmailGateScreen> createState() => _EmailGateScreenState();
}

class _EmailGateScreenState extends State<EmailGateScreen> {
  String _email = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  Future<void> _loadEmail() async {
    var email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (email.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        email = prefs.getString('onboarding_email') ?? '';
      } catch (_) {}
    }
    if (mounted) setState(() {
      _email = email;
      _ready = true;
    });
  }

  void _goMain() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  void _skip() {
    try {
      AnalyticsService.instance.logEvent('email_gate_skipped');
    } catch (_) {}
    _goMain();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: AppBackground(
        backgroundImage: 'assets/photos/elements/onboarding.webp',
        overlayOpacity: 0.35,
        child: SafeArea(
          child: !_ready
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: CheckEmailScreen(
                          email: _email,
                          title:
                              'Check your email to complete registration',
                          hideSkip: true,
                          onUnlocked: _goMain,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _skip,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'Skip for now',
                        style: tt.headlineSmall?.copyWith(
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
        ),
      ),
    );
  }
}
