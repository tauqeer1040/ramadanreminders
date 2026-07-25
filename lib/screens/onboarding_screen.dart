import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../services/shop_service.dart';
import '../services/analytics_service.dart';
import '../services/version_check_service.dart';
import 'main_screen.dart';
import '../components/onboarding/onboarding_data.dart';
import '../components/onboarding/intro_pages.dart';
import '../components/onboarding/final_pages.dart';
import '../core/app_background.dart';
import '../components/widgets/step_progress_dots.dart';
import 'google_signin_page.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onReady;
  const OnboardingScreen({this.onReady, super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  final _data = OnboardingData();
  int _currentPage = 0;
  int _stars = 0;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  static const int _totalPages = 14;

  final List<String> _pageNames = [
    'welcome', 'music_selection', 'name', 'age_phone', 'bombshell',
    'bombshell2', 'bombshell3', 'bridge',
    'first_journal', 'ai_insight', 'celebration',
    'summary', 'app_feedback', 'google_signin',
  ];

  String _ageBracket(int age) {
    if (age < 18) return 'under_18';
    if (age < 25) return '18_24';
    if (age < 35) return '25_34';
    if (age < 50) return '35_49';
    return '50_plus';
  }

  String _hoursBucket(int hours) {
    if (hours <= 2) return '0_2';
    if (hours <= 4) return '3_4';
    if (hours <= 6) return '5_6';
    if (hours <= 8) return '7_8';
    return '9_plus';
  }

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logOnboardingStarted();
    AnalyticsService.instance.logOnboardingPageViewed(_pageNames[0]);
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onReady?.call();
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _addStars([int amount = 10]) {
    setState(() => _stars += amount);
    _bounceController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _goToNext() {
    if (_currentPage != 9) {
      if (_currentPage == 8) {
        _addStars(50);
      } else {
        _addStars(10);
      }
    }
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
  }

  void _goBack() {
    int deduct = 10;
    if (_currentPage == 9) {
      deduct = 50;
    } else if (_currentPage == 10) {
      deduct = 0;
    }
    setState(() => _stars = (_stars - deduct).clamp(0, 990));
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    AnalyticsService.instance.logOnboardingComplete();
    AnalyticsService.instance.setUserProperty('onboarding_completed', 'true');
    if (_data.age != null) {
      AnalyticsService.instance.setUserProperty('user_age_bracket', _ageBracket(_data.age!));
    }
    if (_data.phoneHours != null) {
      AnalyticsService.instance.setUserProperty('user_phone_hours_bucket', _hoursBucket(_data.phoneHours!));
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    await prefs.setString('onboarding_displayName', _data.displayName ?? '');
    if (_data.age != null) await prefs.setInt('onboarding_age', _data.age!);
    if (_data.phoneHours != null) {
      await prefs.setInt('onboarding_phoneHours', _data.phoneHours!);
    }
    if (_data.catName != null) {
      await prefs.setString('onboarding_catName', _data.catName!);
    }
    if (_data.intentionAnswer != null) {
      await prefs.setString('onboarding_intention', _data.intentionAnswer!);
    }
    if (_data.heartAnswer != null) {
      await prefs.setString('onboarding_heart', _data.heartAnswer!);
    }
    if (_data.challengeAnswer != null) {
      await prefs.setString('onboarding_challenge', _data.challengeAnswer!);
    }
    if (_data.journeyAnswer != null) {
      await prefs.setString('onboarding_journey', _data.journeyAnswer!);
    }
    if (_data.commitmentLevel != null) {
      await prefs.setString('onboarding_commitment', _data.commitmentLevel!);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (_data.displayName != null) {
        await user.updateDisplayName(_data.displayName);
      }
      await UserService.syncUser(user);
    }

    await prefs.setInt('total_stars', _stars);

    // Sync initial star balance to server
    ShopService.setStars(_stars);

    // Unlock the 3 scratch cards shown during onboarding
    for (final id in _data.scratchCardIds) {
      await ShopService.unlockItem(id);
    }

    if (mounted) {
      final result = await VersionCheckService.check();
      if (result != null && mounted) {
        if (result.requiresUpdate) {
          await VersionCheckService.showUpdateDialog(context, result, force: true);
        } else if (result.hasUpdate) {
          await VersionCheckService.showUpdateDialog(context, result, force: false);
        }
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  void _showQuitConfirmation() {
    AnalyticsService.instance.logOnboardingAbandoned(
      _currentPage < _pageNames.length ? _pageNames[_currentPage] : 'unknown',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave onboarding?'),
        content: const Text('You can restart anytime from your profile.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainScreen()),
                (route) => false,
              );
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentPage == 0) {
          _showQuitConfirmation();
        } else {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        resizeToAvoidBottomInset: false,
        body: AppBackground(
          backgroundImage: 'assets/photos/elements/onboarding.png',
          overlayOpacity: 0.35,
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(cs),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) {
                      setState(() => _currentPage = i);
                      if (i < _pageNames.length) {
                        AnalyticsService.instance.logOnboardingPageViewed(_pageNames[i]);
                      }
                    },
                    children: _buildPages(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentPage + 1} of $_totalPages',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: AppTheme.starGold, size: 16),
                    const SizedBox(width: 4),
                    AnimatedBuilder(
                      animation: _bounceAnimation,
                      builder: (context, child) => Transform.scale(
                        scale: _bounceAnimation.value,
                        child: child,
                      ),
                      child: Text(
                        '$_stars',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StepProgressDots(
            totalSteps: _totalPages,
            currentStep: _currentPage,
            height: 8,
            spacing: 6,
            animateActiveWidth: true,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPages() {
    return [
      // PART 1: INTRODUCTION (Screens 1-6)
      WelcomePage(onNext: _goToNext),
      MusicSelectionPage(onNext: _goToNext, onBack: _goBack),
      NamePage(data: _data, onNext: _goToNext, onBack: _goBack),
      AgePhonePage(data: _data, onNext: _goToNext, onBack: _goBack),
      BombshellPage(data: _data, onNext: _goToNext, onBack: _goBack),
      BombshellPage2(data: _data, onNext: _goToNext, onBack: _goBack),
      BombshellPage3(data: _data, onNext: _goToNext, onBack: _goBack),
      BridgePage(data: _data, onNext: _goToNext, onBack: _goBack),

      // PART 2: FIRST JOURNAL
      FirstJournalPage(data: _data, onNext: _goToNext, onBack: _goBack),
      AiInsightPage(data: _data, onNext: _goToNext, onBack: _goBack, onStarsEarned: _addStars),
      CelebrationPage(data: _data, onNext: _goToNext, onBack: _goBack),

      // PART 3: CONCLUSION
      SummaryPage(data: _data, onNext: _goToNext, onBack: _goBack),
      AppFeedbackPage(data: _data, onNext: _goToNext, onBack: _goBack),
      GoogleSignInPage(onFinish: _finishOnboarding, onBack: _goBack),
    ];
  }
}
