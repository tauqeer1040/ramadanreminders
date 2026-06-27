import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import '../components/widgets/duo_button.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 32),
              child: Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: AppTheme.starWhite, size: 28),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _AppHeader(),
            const SizedBox(height: 24),
            const _ActionButtons(),
            const SizedBox(height: 12),
            const _JoinWhatsAppButton(),
            const SizedBox(height: 32),
            const _OtherAppsSection(),
            const SizedBox(height: 24),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Made with ❤️ — tauqeer ahmed (solo dev)',
          style: TextStyle(
            color: AppTheme.ghostSilver,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _PrivacyPolicyLink(),
        const SizedBox(height: 24),
        _ReplayButton(),
      ],
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
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
          backgroundColor: const Color(0xFFE91E63),
          depthColor: const Color(0xFFAD1457),
          radius: 16,
          height: 56,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.share_rounded, color: AppTheme.starWhite, size: 20),
              SizedBox(width: 10),
              Text(
                'Share with Friends +100 ⭐',
                style: TextStyle(
                  color: AppTheme.starWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _JoinWhatsAppButton extends StatelessWidget {
  const _JoinWhatsAppButton();

  static const String _whatsAppUrl = 'https://chat.whatsapp.com/FDyQLduHssu4Ylh3t1sqTB?s=sh&p=a&ilr=0';

  @override
  Widget build(BuildContext context) {
    return DuoButton(
      onPressed: () async {
        HapticFeedback.lightImpact();
        final uri = Uri.parse(_whatsAppUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open WhatsApp. Please install WhatsApp first.')),
            );
          }
        }
      },
      backgroundColor: const Color(0xFF25D366),
      depthColor: const Color(0xFF128C7E),
      radius: 16,
      height: 56,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_rounded, color: AppTheme.starWhite, size: 20),
          SizedBox(width: 10),
          Text(
            'Join WhatsApp Group',
            style: TextStyle(
              color: AppTheme.starWhite,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Meowstian — coming soon!'),
                      backgroundColor: AppTheme.neonPurple,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/photos/elements/meowstian.webp',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                              child: const Icon(Icons.auto_stories_rounded, color: Color(0xFF8B5CF6), size: 22),
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
                              'Meowstian',
                              style: TextStyle(
                                color: AppTheme.starWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Same as this app, but for Christians about the Bible.',
                              style: TextStyle(
                                color: AppTheme.ghostSilver,
                                fontSize: 11,
                                height: 1.3,
                              ),
                              maxLines: 2,
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

class _PrivacyPolicyLink extends StatelessWidget {
  const _PrivacyPolicyLink();

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_rounded, color: AppTheme.neonPurple, size: 24),
            SizedBox(width: 10),
            Text('Privacy Policy', style: TextStyle(color: AppTheme.starWhite, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: DefaultTextStyle(
            style: const TextStyle(color: AppTheme.ghostSilver, fontSize: 13, height: 1.6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _p('Last updated: May 2026'),
                _p('Meowmin Ai Diary ("we", "our", "app") respects your privacy. This policy explains how we handle your data.'),
                _section('Data We Collect'),
                _p('• Journal entries you write (stored securely on our server)\n• Email and display name (if you sign in with Google)\n• Approximate location (only for prayer time calculation)\n• Device information for push notifications'),
                _section('How We Use Data'),
                _p('• Journal text is processed by AI (OpenRouter) to generate insights and suggested tasks\n• Location is used locally for adhan prayer times — never uploaded or shared\n• Email is used only for account identification'),
                _section('Data Sharing'),
                _p('We do not sell your data. Journal content is sent to OpenRouter for AI analysis. Payments are processed by Superwall and Google Play — we never see your payment details.'),
                _section('Data Deletion'),
                _p('You can delete your account and all associated data from Profile → Delete Account. Data is permanently removed within 30 days.'),
                _section('Contact'),
                _p('Questions? Reach out at meowmin.app@tauqeer.dev'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: AppTheme.neonPurple)),
          ),
        ],
      ),
    );
  }

  Widget _p(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text),
  );

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(title, style: const TextStyle(color: AppTheme.starWhite, fontWeight: FontWeight.bold, fontSize: 14)),
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _showPrivacyPolicy(context);
      },
      child: const Text(
        'Privacy Policy',
        style: TextStyle(
          color: AppTheme.ghostSilver,
          fontSize: 12,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class _ReplayButton extends StatelessWidget {
  const _ReplayButton();
  @override
  Widget build(BuildContext context) {
    return DuoButton(
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
      backgroundColor: AppTheme.neonPurple,
      depthColor: AppTheme.neonPurple.withValues(alpha: 0.7),
      radius: 16,
      height: 56,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.replay, color: AppTheme.starWhite, size: 20),
          SizedBox(width: 10),
          Text(
            'Replay Onboarding',
            style: TextStyle(
              color: AppTheme.starWhite,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
