import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../screens/onboarding_screen.dart';
import 'widgets/duo_button.dart';

class AboutBottomSheet extends StatelessWidget {
  const AboutBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const _AppHeader(),
          const SizedBox(height: 24),
          const _ActionButtons(),
          const SizedBox(height: 32),
          const _OtherAppsSection(),
          const SizedBox(height: 24),
          const Text(
            'Made with ❤️ — tauqeer ahmed (solo dev)',
            style: TextStyle(
              color: AppTheme.ghostSilver,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          _ReplayButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.neonPurple.withValues(alpha: 0.4),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/photos/mascot/hi.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.neonPurple.withValues(alpha: 0.2),
                child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.neonPurple, size: 40),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Meowmin Ai Diary',
          style: TextStyle(
            color: AppTheme.starWhite,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.neonPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.3)),
          ),
          child: const Text(
            'Version 1.0.0',
            style: TextStyle(
              color: AppTheme.starWhite,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'A journaling companion for your spiritual journey.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.ghostSilver,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DuoButton(
          onPressed: () async {
            HapticFeedback.lightImpact();
            final InAppReview inAppReview = InAppReview.instance;
            if (await inAppReview.isAvailable()) {
              inAppReview.requestReview();
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Review not available on this device.')),
                );
              }
            }
          },
          backgroundColor: AppTheme.neonPurple,
          depthColor: const Color(0xFF6A00FF),
          radius: 16,
          height: 56,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.star_rounded, color: AppTheme.starWhite, size: 22),
              SizedBox(width: 10),
              Text(
                'Leave a Review',
                style: TextStyle(
                  color: AppTheme.starWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DuoButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Share.share(
              '🌙 Check out Meowmin Ai Diary! A beautiful journaling companion for your spiritual journey.\n\nDownload: https://play.google.com/store/apps/details?id=com.taucity.ramadanreflections',
            );
          },
          backgroundColor: const Color(0xFF1E1E2E).withValues(alpha: 0.8),
          depthColor: const Color(0xFF0D0D1A),
          radius: 16,
          height: 56,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.share_rounded, color: AppTheme.starWhite, size: 22),
              SizedBox(width: 10),
              Text(
                'Share with Friends',
                style: TextStyle(
                  color: AppTheme.starWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OtherAppsSection extends StatelessWidget {
  const _OtherAppsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Check out',
            style: TextStyle(
              color: AppTheme.starGold,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF2A2A4A).withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Text(
                'OUR OTHER APPS',
                style: TextStyle(
                  color: AppTheme.ghostSilver,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Hyderabad Trivia — coming soon!'),
                      backgroundColor: AppTheme.neonPurple,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/photos/elements/hyderabad_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.neonPurple.withValues(alpha: 0.1),
                              child: const Icon(Icons.landscape_rounded, color: AppTheme.neonPurple, size: 28),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hyderabad Trivia',
                              style: TextStyle(
                                color: AppTheme.starWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'A soulful journey through the heart of Hyderabad, told through vibrant art and hidden stories.',
                              style: TextStyle(
                                color: AppTheme.ghostSilver,
                                fontSize: 12,
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _ReplayButton extends StatelessWidget {
  const _ReplayButton();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('onboarding_complete', false);
          if (context.mounted) {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const OnboardingScreen(),
                fullscreenDialog: true,
              ),
            );
          }
        },
        icon: const Icon(Icons.replay_rounded, size: 18),
        label: const Text('Replay Onboarding'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.ghostSilver,
          side: BorderSide(color: AppTheme.ghostSilver.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
