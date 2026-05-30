import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../components/onboarding/onboarding_data.dart';
import '../components/onboarding/intro_pages.dart';
import '../components/onboarding/analogy_pages.dart';
import '../components/onboarding/final_pages.dart';
import '../core/app_background.dart';
import '../components/widgets/duo_progress_bar.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

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

  static const int _totalPages = 20;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _addStars() {
    setState(() => _stars += 10);
    _bounceController.forward(from: 0);
    HapticFeedback.heavyImpact();
  }

  void _goToNext() {
    _addStars();
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
  }

  void _goBack() {
    setState(() => _stars = (_stars - 10).clamp(0, 990));
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (_data.displayName != null) {
        await user.updateDisplayName(_data.displayName);
      }
      await UserService.syncUser(user);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showQuitConfirmation() {
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
              Navigator.of(context).pop();
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
                    onPageChanged: (i) => setState(() => _currentPage = i),
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
          DuoProgressBar(
            progress: (_currentPage + 1) / _totalPages,
            height: 12,
            radius: 12,
            trackColor: cs.surfaceContainerHighest.withOpacity(0.5),
            fillColor: cs.primary,
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
      BridgePage(onNext: _goToNext, onBack: _goBack),

      // PART 2: REFLECTION BANK — AI ANALOGIES (Screens 7-14)
      // Q1: Intention
      AnalogyQuestionPage(
        data: _data,
        question: "What do you seek most in your journey to Allah?",
        pills: ["Deeper connection with Allah", "Quran consistency", "Self-discipline", "Gratitude & contentment"],
        dataField: 'intention',
        useDuoButtons: true,
        onNext: _goToNext,
        onBack: _goBack,
      ),
      AnalogyRevealPage(
        data: _data,
        question: "What do you seek most in your journey to Allah?",
        analogyField: 'intention',
        onNext: _goToNext,
        onBack: _goBack,
      ),

      // Q2: Heart
      AnalogyQuestionPage(
        data: _data,
        question: "How does your heart feel right now?",
        pills: ["Restless / Yearning", "Grateful / At peace", "Overwhelmed / Heavy", "Hopeful / Excited"],
        dataField: 'heart',
        useDuoButtons: true,
        onNext: _goToNext,
        onBack: _goBack,
      ),
      AnalogyRevealPage(
        data: _data,
        question: "How does your heart feel right now?",
        analogyField: 'heart',
        onNext: _goToNext,
        onBack: _goBack,
      ),

      // Q3: Challenge
      AnalogyQuestionPage(
        data: _data,
        question: "What's your biggest spiritual barrier?",
        pills: ["Finding time", "Staying consistent", "Phone distractions", "Lack of motivation"],
        dataField: 'challenge',
        useDuoButtons: true,
        onNext: _goToNext,
        onBack: _goBack,
      ),
      AnalogyRevealPage(
        data: _data,
        question: "What's your biggest spiritual barrier?",
        analogyField: 'challenge',
        onNext: _goToNext,
        onBack: _goBack,
      ),

      // Q4: Journey
      AnalogyQuestionPage(
        data: _data,
        question: "How would you describe your spiritual walk?",
        pills: ["I want to grow closer to Allah", "I'm trying my best, but...", "I feel distant but want to return", "I'm hopeful and excited"],
        dataField: 'journey',
        useDuoButtons: true,
        onNext: _goToNext,
        onBack: _goBack,
      ),
      AnalogyRevealPage(
        data: _data,
        question: "How would you describe your spiritual walk?",
        analogyField: 'journey',
        isLast: true,
        onNext: _goToNext,
        onBack: _goBack,
      ),

      // PART 3: CLIMAX (Screens 15-17)
      FirstJournalPage(data: _data, onNext: _goToNext, onBack: _goBack),
      AiInsightPage(data: _data, onNext: _goToNext, onBack: _goBack),
      CelebrationPage(data: _data, onNext: _goToNext, onBack: _goBack),

      // PART 4: CONCLUSION (Screens 18-20)
      SummaryPage(data: _data, onNext: _goToNext, onBack: _goBack),
      CommitmentPage(data: _data, onNext: _goToNext, onBack: _goBack),
      SetupPage(data: _data, onFinish: _finishOnboarding, onBack: _goBack),
    ];
  }
}
