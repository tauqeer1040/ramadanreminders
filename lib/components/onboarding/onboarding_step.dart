import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'intro_pages.dart';
import 'final_pages.dart';
import 'pages/age_phone_page.dart';
import 'pages/bombshell_page1.dart';
import 'pages/bombshell_page2.dart';
import 'pages/bombshell_page3.dart';
import 'pages/bridge_page.dart';
import '../../screens/google_signin_page.dart' show GoogleSignInPage;

sealed class OnboardingStep {
  final int index;
  final String name;

  const OnboardingStep(this.index, this.name);

  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin});

  static const List<OnboardingStep> all = [
    _WelcomeStep(0),
    _MusicSelectionStep(1),
    _NameStep(2),
    _AgePhoneStep(3),
    _Bombshell1Step(4),
    _Bombshell2Step(5),
    _Bombshell3Step(6),
    _BridgeStep(7),
    _FirstJournalStep(8),
    _AiInsightStep(9),
    _CelebrationStep(10),
    _SummaryStep(11),
    _AppFeedbackStep(12),
    _GoogleSignInStep(13),
  ];

  static OnboardingStep fromIndex(int i) => all.firstWhere((s) => s.index == i);
}

class _WelcomeStep extends OnboardingStep {
  const _WelcomeStep(int i) : super(i, 'welcome');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      WelcomePage(onNext: onNext, onSkipToLogin: onSkipToLogin);
}

class _MusicSelectionStep extends OnboardingStep {
  const _MusicSelectionStep(int i) : super(i, 'music_selection');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      MusicSelectionPage(onNext: onNext, onBack: onBack);
}

class _NameStep extends OnboardingStep {
  const _NameStep(int i) : super(i, 'name');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      NamePage(data: data, onNext: onNext, onBack: onBack);
}

class _AgePhoneStep extends OnboardingStep {
  const _AgePhoneStep(int i) : super(i, 'age_phone');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      AgePhonePage(data: data, onNext: onNext, onBack: onBack);
}

class _Bombshell1Step extends OnboardingStep {
  const _Bombshell1Step(int i) : super(i, 'bombshell');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      BombshellPage1(data: data, onNext: onNext, onBack: onBack);
}

class _Bombshell2Step extends OnboardingStep {
  const _Bombshell2Step(int i) : super(i, 'bombshell2');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      BombshellPage2(data: data, onNext: onNext, onBack: onBack);
}

class _Bombshell3Step extends OnboardingStep {
  const _Bombshell3Step(int i) : super(i, 'bombshell3');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      BombshellPage3(data: data, onNext: onNext, onBack: onBack);
}

class _BridgeStep extends OnboardingStep {
  const _BridgeStep(int i) : super(i, 'bridge');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      BridgePage(data: data, onNext: onNext, onBack: onBack);
}

class _FirstJournalStep extends OnboardingStep {
  const _FirstJournalStep(int i) : super(i, 'first_journal');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      FirstJournalPage(data: data, onNext: onNext, onBack: onBack);
}

class _AiInsightStep extends OnboardingStep {
  const _AiInsightStep(int i) : super(i, 'ai_insight');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      AiInsightPage(data: data, onNext: onNext, onBack: onBack);
}

class _CelebrationStep extends OnboardingStep {
  const _CelebrationStep(int i) : super(i, 'celebration');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      CelebrationPage(data: data, onNext: onNext, onBack: onBack);
}

class _SummaryStep extends OnboardingStep {
  const _SummaryStep(int i) : super(i, 'summary');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      SummaryPage(data: data, onNext: onNext, onBack: onBack);
}

class _AppFeedbackStep extends OnboardingStep {
  const _AppFeedbackStep(int i) : super(i, 'app_feedback');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      AppFeedbackPage(data: data, onNext: onNext, onBack: onBack);
}

class _GoogleSignInStep extends OnboardingStep {
  const _GoogleSignInStep(int i) : super(i, 'google_signin');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin}) =>
      GoogleSignInPage(onFinish: onNext, onBack: onBack);
}
