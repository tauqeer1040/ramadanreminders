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

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _data = OnboardingData();
  int _currentPage = 0;

  static const int _totalPages = 20;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNext() {
    HapticFeedback.lightImpact();
    if (_currentPage < _totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
  }

  void _goBack() {
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

  static const Color _starlightWhite = Color(0xFFF5F5F0);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: cs.copyWith(
          brightness: Brightness.dark,
          onSurface: _starlightWhite,
          onSurfaceVariant: const Color(0xFFE0E0DA),
        ),
      ),
      child: PopScope(
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
        body: AppBackground(
          backgroundImage: 'assets/photos/elements/onboarding.png',
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
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '8 🌟', // Changed eggplant to a star or leave it out. We can just use standard emoji.
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              _totalPages,
              (index) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 4,
                  decoration: BoxDecoration(
                    color: index <= _currentPage
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
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
      BombshellPage(data: _data, onNext: _goToNext),
      BridgePage(onNext: _goToNext),

      // PART 2: REFLECTION BANK — AI ANALOGIES (Screens 7-14)
      // Q1: Intention
      AnalogyQuestionPage(
        data: _data,
        question: "What do you want most from this Ramadan?",
        pills: ["Deeper connection with Allah", "Quran consistency", "Self-discipline", "Gratitude & contentment"],
        dataField: 'intention',
        onNext: _goToNext,
      ),
      AnalogyRevealPage(
        data: _data,
        question: "What do you want most from this Ramadan?",
        analogyField: 'intention',
        onNext: _goToNext,
      ),

      // Q2: Heart
      AnalogyQuestionPage(
        data: _data,
        question: "How does your heart feel right now?",
        pills: ["Restless / Yearning", "Grateful / At peace", "Overwhelmed / Heavy", "Hopeful / Excited"],
        dataField: 'heart',
        onNext: _goToNext,
      ),
      AnalogyRevealPage(
        data: _data,
        question: "How does your heart feel right now?",
        analogyField: 'heart',
        onNext: _goToNext,
      ),

      // Q3: Challenge
      AnalogyQuestionPage(
        data: _data,
        question: "What's your biggest barrier this Ramadan?",
        pills: ["Finding time", "Staying consistent", "Phone distractions", "Lack of motivation"],
        dataField: 'challenge',
        onNext: _goToNext,
      ),
      AnalogyRevealPage(
        data: _data,
        question: "What's your biggest barrier this Ramadan?",
        analogyField: 'challenge',
        onNext: _goToNext,
      ),

      // Q4: Journey
      AnalogyQuestionPage(
        data: _data,
        question: "Write a reflection about your Ramadan so far",
        pills: ["I want this Ramadan to be different", "I'm trying my best, but...", "I feel distant but want to return", "I'm excited for what's ahead"],
        dataField: 'journey',
        onNext: _goToNext,
      ),
      AnalogyRevealPage(
        data: _data,
        question: "Write a reflection about your Ramadan so far",
        analogyField: 'journey',
        isLast: true,
        onNext: _goToNext,
      ),

      // PART 3: CLIMAX (Screens 15-17)
      FirstJournalPage(data: _data, onNext: _goToNext),
      AiInsightPage(data: _data, onNext: _goToNext),
      CelebrationPage(data: _data, onNext: _goToNext),

      // PART 4: CONCLUSION (Screens 18-20)
      SummaryPage(data: _data, onNext: _goToNext),
      CommitmentPage(data: _data, onNext: _goToNext),
      SetupPage(data: _data, onFinish: _finishOnboarding),
    ];
  }
}
