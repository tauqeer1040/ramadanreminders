import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../services/shop_service.dart';
import '../services/analytics_service.dart';
import '../services/version_check_service.dart';
import '../services/local_trial_service.dart';
import '../services/revenuecat_service.dart';
import 'main_screen.dart';
import 'paywall_gate_screen.dart';
import '../components/onboarding/onboarding_data.dart';
import '../components/onboarding/onboarding_step.dart';
import '../core/app_background.dart';
import '../components/widgets/step_progress_dots.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onReady;
  const OnboardingScreen({this.onReady, super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pageController = PageController();
  final _data = OnboardingData();
  late OnboardingStep _currentStep;
  int _currentIndex = 0;

  // Star tracking
  int _totalStars = 0;
  int _oldStars = 0;
  // 18 steps: Welcome, Music, Name, Intention, MillionDollars, Wakeup, Conclusion, PhoneHours, Bombshell1, Bombshell2, Bombshell3, Bridge, FirstJournal, AiInsight, Celebration, Summary, AppFeedback, GoogleSignIn (Qualifying hidden, replaced by RevenueCat popup)
  static const List<int> _stepStars = [
    5,  5,  10, // Welcome, Music, Name (action: user types name)
    5,  5,  5,  5,  30, // Intention, MillionDollars, Wakeup, Conclusion, PhoneHours (fingerprint reward)
    5,  5,  10, 10, // Bombshell1, Bombshell2, Bombshell3, Bridge
    50, 60, // FirstJournal (action: write journal), AiInsight (action: scratch cards)
    15, 15, // Celebration, Summary
    0,  0, // AppFeedback, GoogleSignIn (Qualifying hidden)
  ];

  @override
  void initState() {
    super.initState();
    _currentStep = OnboardingStep.fromIndex(0);
    _totalStars = _stepStars[0]; // Start with first step's stars
    AnalyticsService.instance.logEvent('onboarding_started');
    _logPageView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onReady?.call();
    });
  }

  void _logPageView() {
    AnalyticsService.instance.logEvent('onboarding_page_viewed', params: {'page': _currentStep.name});
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _updateStars() {
    int total = 0;
    for (int i = 0; i <= _currentIndex && i < _stepStars.length; i++) {
      total += _stepStars[i];
    }
    setState(() {
      _oldStars = _totalStars;
      _totalStars = total;
    });
  }

  void _goToNext() {
    if (_currentIndex < OnboardingStep.all.length - 1) {
      _currentIndex++;
      _currentStep = OnboardingStep.fromIndex(_currentIndex);
      _updateStars();
      _logPageView();
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _goBack() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _currentStep = OnboardingStep.fromIndex(_currentIndex);
      _updateStars();
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
  }

  void _goToStep(int index) {
    if (index >= 0 && index < OnboardingStep.all.length) {
      _currentIndex = index;
      _currentStep = OnboardingStep.fromIndex(index);
      _updateStars();
      _logPageView();
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
  }

  void _skipToLogin() {
    final loginIndex = OnboardingStep.all.length - 1;
    _currentIndex = loginIndex;
    _currentStep = OnboardingStep.fromIndex(_currentIndex);
    _logPageView();
    _pageController.animateToPage(
      loginIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubicEmphasized,
    );
  }

  Future<void> _finishOnboarding() async {
    AnalyticsService.instance.logEvent('onboarding_complete');
    AnalyticsService.instance.setUserProperty('onboarding_completed', 'true');
    if (_data.age != null) {
      AnalyticsService.instance.setUserProperty(
        'user_age_bracket',
        _ageBracket(_data.age!),
      );
    }
    if (_data.phoneHours != null) {
      AnalyticsService.instance.setUserProperty(
        'user_phone_hours_bucket',
        _hoursBucket(_data.phoneHours!),
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setString('onboarding_displayName', _data.displayName ?? '');
    // Verify the flag was written (defensive against platform bugs)
    await prefs.reload();
    assert(prefs.getBool('onboarding_complete') == true, 'onboarding_complete failed to persist');
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

    await ShopService.awardStars('onboarding_complete');
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

      // Hide Qualifying page — start 3-day trial and show RevenueCat popup (dismissable for 3 days)
      if (!await LocalTrialService.hasStarted()) {
        await LocalTrialService.startTrial();
      }
      final isSubscribed = await RevenueCatService.instance.isSubscribed();
      if (isSubscribed) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => PaywallGateScreen(
              isDismissable: true, // first popup dismissable for 3 days; Splash will show hard paywall after expiry
              onSubscribe: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                  (route) => false,
                );
              },
              onDismiss: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                  (route) => false,
                );
              },
            ),
          ),
          (route) => false,
        );
      }
    }
  }

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

  void _showQuitConfirmation() {
    AnalyticsService.instance.logEvent('onboarding_abandoned', params: {'page': _currentStep.name});
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
    final totalPages = OnboardingStep.all.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentIndex == 0) {
          _showQuitConfirmation();
        } else {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        resizeToAvoidBottomInset: false,
        body: AppBackground(
          backgroundImage: 'assets/photos/elements/onboarding.webp',
          overlayOpacity: 0.35,
          child: SafeArea(
            child: Column(
              children: [
                _buildTopBar(cs, totalPages),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) {
                      setState(() {
                        _currentIndex = i;
                        _currentStep = OnboardingStep.fromIndex(i);
                      });
                      _logPageView();
                    },
                    children: OnboardingStep.all.map(
                      (step) => step.buildPage(_data, _goToNext, _goBack, onSkipToLogin: _skipToLogin, onGoToStep: _goToStep, onStarsEarned: (amount) {
                        setState(() {
                          _oldStars = _totalStars;
                          _totalStars += amount;
                        });
                      }),
                    ).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme cs, int totalPages) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentIndex + 1} of $totalPages',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TweenAnimationBuilder<double>(
                key: ValueKey(_totalStars),
                tween: Tween(begin: 1.0, end: 1.3),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: scale, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, finalScale, child) {
                      return Transform.scale(scale: finalScale, child: child);
                    },
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.starGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.starGold.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, color: AppTheme.starGold, size: 16),
                      const SizedBox(width: 6),
                      TweenAnimationBuilder<int>(
                        tween: IntTween(begin: _oldStars, end: _totalStars),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Text(
                            '$value',
                            style: TextStyle(
                              color: AppTheme.starGold,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StepProgressDots(
            totalSteps: totalPages,
            currentStep: _currentIndex,
            height: 8,
            spacing: 6,
            animateActiveWidth: true,
          ),
        ],
      ),
    );
  }
}
