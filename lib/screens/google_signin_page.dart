import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
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

  Future<void> _signIn() async {
    setState(() => _loading = true);
    try {
      await AuthService.signInWithGoogle();
      if (mounted) widget.onFinish();
    } catch (_) {
      // error handled inside signInWithGoogle
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            "Save your diaries and progress",
            textAlign: TextAlign.center,
            style: tt.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your data is private and safe.\nOnly you can see your reflections.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.ghostSilver.withValues(alpha: 0.75),
              fontSize: 15,
            ),
          ),
          const Spacer(),

          // Google sign-in button (classic white style)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.3),
              child: InkWell(
                onTap: _loading ? null : _signIn,
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
                          Image.asset(
                            'assets/photos/elements/googlelogo.png',
                            width: 22,
                            height: 22,
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            "Sign in with Google",
                            style: TextStyle(
                              color: Color(0xFF1F1F1F),
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
          const SizedBox(height: 16),
          GestureDetector(
            onTap: widget.onFinish,
            child: Text(
              "Skip for now",
              style: TextStyle(
                color: AppTheme.ghostSilver.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const Spacer(),
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
                  onPressed: widget.onFinish,
                  backgroundColor: cs.primary,
                  depthColor: cs.primary.withValues(alpha: 0.8),
                  radius: 16,
                  height: 56,
                  sfxType: DuoSfxType.positive,
                  child: Text(
                    "Continue",
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
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
