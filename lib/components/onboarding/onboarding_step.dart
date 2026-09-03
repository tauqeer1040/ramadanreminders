import 'package:flutter/material.dart';
import 'onboarding_data.dart';
import 'intro_pages.dart';
import 'final_pages.dart';
import 'pages/age_phone_page.dart';
import 'pages/bombshell_page1.dart';
import 'pages/bombshell_page2.dart';
import 'pages/bombshell_page3.dart';
import 'pages/bridge_page.dart';
import 'pages/qualifying_page.dart';
import '../../screens/google_signin_page.dart' show GoogleSignInPage;

sealed class OnboardingStep {
  final int index;
  final String name;

  const OnboardingStep(this.index, this.name);

  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned});

  static const List<OnboardingStep> all = [
    _WelcomeStep(0),
    _MusicSelectionStep(1),
    _NameStep(2),
    _IntentionStep(3),
    _MillionDollarsStep(4),
    _WakeupStep(5),
    _ConclusionStep(6),
    _PhoneHoursStep(7),
    _Bombshell1Step(8),
    _Bombshell2Step(9),
    _Bombshell3Step(10),
    _BridgeStep(11),
    _FirstJournalStep(12),
    _AiInsightStep(13),
    _CelebrationStep(14),
    _SummaryStep(15),
    _AppFeedbackStep(16),
    _GoogleSignInStep(17),
    // _QualifyingStep hidden — replaced by RevenueCat popup after Google sign-in
  ];

  static OnboardingStep fromIndex(int i) => all.firstWhere((s) => s.index == i);
}

class _WelcomeStep extends OnboardingStep {
  const _WelcomeStep(int i) : super(i, 'welcome');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      WelcomePage(onNext: onNext, onSkipToLogin: onSkipToLogin);
}

class _MusicSelectionStep extends OnboardingStep {
  const _MusicSelectionStep(int i) : super(i, 'music_selection');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      MusicSelectionPage(onNext: onNext, onBack: onBack);
}

class _NameStep extends OnboardingStep {
  const _NameStep(int i) : super(i, 'name');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      NamePage(data: data, onNext: onNext, onBack: onBack);
}

class _IntentionStep extends OnboardingStep {
  const _IntentionStep(int i) : super(i, 'intention');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      IntentionPage(data: data, onNext: onNext, onBack: onBack, onGoToStep: onGoToStep!);
}

class _MillionDollarsStep extends OnboardingStep {
  const _MillionDollarsStep(int i) : super(i, 'million_dollars');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      MillionDollarsPage(onNext: onNext, onBack: onBack);
}

class _WakeupStep extends OnboardingStep {
  const _WakeupStep(int i) : super(i, 'wakeup');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      WakeupPage(onNext: onNext, onBack: onBack);
}

class _ConclusionStep extends OnboardingStep {
  const _ConclusionStep(int i) : super(i, 'conclusion');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      ConclusionPage(data: data, onNext: onNext, onBack: onBack);
}

class _PhoneHoursStep extends OnboardingStep {
  const _PhoneHoursStep(int i) : super(i, 'phone_hours');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      PhoneHoursPage(data: data, onNext: onNext, onBack: onBack);
}

class _Bombshell1Step extends OnboardingStep {
  const _Bombshell1Step(int i) : super(i, 'bombshell');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      BombshellPage1(data: data, onNext: onNext, onBack: onBack);
}

class _Bombshell2Step extends OnboardingStep {
  const _Bombshell2Step(int i) : super(i, 'bombshell2');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      BombshellPage2(data: data, onNext: onNext, onBack: onBack);
}

class _Bombshell3Step extends OnboardingStep {
  const _Bombshell3Step(int i) : super(i, 'bombshell3');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      BombshellPage3(data: data, onNext: onNext, onBack: onBack);
}

class _BridgeStep extends OnboardingStep {
  const _BridgeStep(int i) : super(i, 'bridge');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      BridgePage(data: data, onNext: onNext, onBack: onBack);
}

class _FirstJournalStep extends OnboardingStep {
  const _FirstJournalStep(int i) : super(i, 'first_journal');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      FirstJournalPage(data: data, onNext: onNext, onBack: onBack);
}

class _AiInsightStep extends OnboardingStep {
  const _AiInsightStep(int i) : super(i, 'ai_insight');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      AiInsightPage(data: data, onNext: onNext, onBack: onBack, onStarsEarned: onStarsEarned);
}

class _CelebrationStep extends OnboardingStep {
  const _CelebrationStep(int i) : super(i, 'celebration');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      CelebrationPage(data: data, onNext: onNext, onBack: onBack);
}

class _SummaryStep extends OnboardingStep {
  const _SummaryStep(int i) : super(i, 'summary');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      SummaryPage(data: data, onNext: onNext, onBack: onBack);
}

class _AppFeedbackStep extends OnboardingStep {
  const _AppFeedbackStep(int i) : super(i, 'app_feedback');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      AppFeedbackPage(data: data, onNext: onNext, onBack: onBack);
}

class _GoogleSignInStep extends OnboardingStep {
  const _GoogleSignInStep(int i) : super(i, 'google_signin');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      GoogleSignInPage(onFinish: onNext, onBack: onBack);
}

class _QualifyingStep extends OnboardingStep {
  const _QualifyingStep(int i) : super(i, 'qualifying');
  @override
  Widget buildPage(OnboardingData data, VoidCallback onNext, VoidCallback onBack, {VoidCallback? onSkipToLogin, void Function(int)? onGoToStep, ValueChanged<int>? onStarsEarned}) =>
      QualifyingPage(data: data, onNext: onNext, onBack: onBack);
}
