import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/analytics_service.dart';
import '../services/revenuecat_service.dart';
import '../components/widgets/duo_button.dart';

class GoogleSignInPage extends StatefulWidget {
  final VoidCallback onFinish;
  final VoidCallback onBack;

  const GoogleSignInPage({
    required this.onFinish,
    required this.onBack,
    super.key,
  });

  @override
  State<GoogleSignInPage> createState() => _GoogleSignInPageState();
}

class _GoogleSignInPageState extends State<GoogleSignInPage> {
  bool _loading = false;
  bool _loggedIn = false;
  String _userName = '';

  Future<void> _signIn() async {
    AnalyticsService.instance.logEvent('onboarding_google_sign_in', params: {'action': 'started'});
    setState(() => _loading = true);
    try {
      final cred = await AuthService.signInWithGoogle();
      AnalyticsService.instance.logEvent('onboarding_google_sign_in', params: {'action': 'completed'});
      // Link the Firebase identity to RevenueCat so web purchases made with
      // this email resolve to Max on next entitlement check. Never blocks login.
      try {
        final uid = cred?.user?.uid;
        if (uid != null && uid.isNotEmpty) {
          await RevenueCatService.instance.identify(uid);
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _loggedIn = true;
          _userName = cred?.user?.displayName ?? cred?.user?.email ?? '';
        });
      }
    } catch (_) {
      AnalyticsService.instance.logEvent('onboarding_google_sign_in', params: {'action': 'failed'});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 1),
          Text(
            _loggedIn ? "You're all set!" : "Save your memories",
            textAlign: TextAlign.center,
            style: tt.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _loggedIn
                ? "Signed in${_userName.isNotEmpty ? ' as $_userName' : ''}.\nTap Continue to enter the app."
                : "Your data is private and safe.\nOnly you can see your reflections.",
            textAlign: TextAlign.center,
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 32),

          // Google sign-in button / logged-in state
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Material(
              color: _loggedIn ? const Color(0xFFE8F5E9) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.3),
              child: InkWell(
                onTap: (_loading || _loggedIn) ? null : _signIn,
                borderRadius: BorderRadius.circular(28),
                child: Center(
                  child: _loading
                    ? const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_loggedIn)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 22)
                          else
                            Image.asset(
                              'assets/photos/elements/googlelogo.webp',
                              width: 22,
                              height: 22,
                            ),
                          const SizedBox(width: 14),
                          Text(
                            _loggedIn ? "Signed in with Google" : "Sign in with Google",
                            style: TextStyle(
                              color: _loggedIn ? const Color(0xFF2E7D32) : const Color(0xFF1F1F1F),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                ),
              ),
            ),
          ),

          const Spacer(flex: 1),
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
                    "Back",
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
                  // Mandatory sign-in: Continue stays disabled until signed in.
                  onPressed: _loggedIn ? widget.onFinish : null,
                  dimOnDisabled: true,
                  backgroundColor: cs.primary,
                  depthColor: cs.primary.withValues(alpha: 0.8),
                  radius: 16,
                  height: 56,
                  sfxType: DuoSfxType.positive,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Continue",
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
    );
  }
}
