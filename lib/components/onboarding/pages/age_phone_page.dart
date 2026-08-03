import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../onboarding_data.dart';
import '../../../services/analytics_service.dart';
import '../../widgets/duo_button.dart';
import '../../widgets/commitment_button.dart';
import '../../../theme/app_theme.dart';

class AgePhonePage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const AgePhonePage({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  State<AgePhonePage> createState() => _AgePhonePageState();
}

class _AgePhonePageState extends State<AgePhonePage> {
  int _age = 25;
  double _phoneHours = 4;
  int _stepIndex = 0;
  bool _chosenHard = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.age != null) _age = widget.data.age!;
    if (widget.data.phoneHours != null) {
      _phoneHours = widget.data.phoneHours!.toDouble();
    }
  }

  void _handleBack() {
    if (_stepIndex == 0) {
      widget.onBack();
    } else if (_stepIndex == 4) {
      if (_chosenHard) {
        setState(() => _stepIndex = 3);
      } else {
        setState(() => _stepIndex = 0);
      }
    } else {
      setState(() => _stepIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildCurrentStep(cs, tt),
      ),
    );
  }

  Widget _buildCurrentStep(ColorScheme cs, TextTheme tt) {
    switch (_stepIndex) {
      case 0:
        return _buildReadyStep(cs, tt);
      case 1:
        return _buildMillionDollarsStep(cs, tt);
      case 2:
        return _buildWakeUpStep(cs, tt);
      case 3:
        return _buildConclusionStep(cs, tt);
      case 4:
        return _buildPhoneHoursStep(cs, tt);
      default:
        return _buildReadyStep(cs, tt);
    }
  }

  Widget _buildReadyStep(ColorScheme cs, TextTheme tt) {
    final catName = widget.data.catName;
    final userName = widget.data.displayName;
    return Column(
      key: const ValueKey('ready_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        Text(
          "Are you ready for a deep reflection${userName != null ? ", $userName" : ""}?",
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "A moment of honest clarity can sometimes bring the most beautiful insights. Are you ready for a hard question${userName != null ? ", $userName" : ""}?",
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.8),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        DuoButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            AnalyticsService.instance.logEvent('onboarding_hard_questions_chosen', params: {'chosen': 'true'});
            setState(() {
              _chosenHard = true;
              _stepIndex = 1;
            });
          },
          backgroundColor: cs.primary,
          depthColor: cs.primary.withValues(alpha: 0.8),
          radius: 16,
          height: 56,
          sfxType: DuoSfxType.positive,
          child: Text(
            "I'm ready${catName != null ? ", $catName" : ""}",
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        DuoButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            AnalyticsService.instance.logEvent('onboarding_hard_questions_chosen', params: {'chosen': 'false'});
            setState(() {
              _chosenHard = false;
              _stepIndex = 4;
            });
          },
          backgroundColor: cs.secondaryContainer,
          depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
          radius: 16,
          height: 56,
          sfxType: DuoSfxType.negative,
          child: Text(
            "No hard questions today, please",
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(flex: 1),
        Row(
          children: [
            Expanded(
              child: DuoButton(
                onPressed: _handleBack,
                backgroundColor: cs.secondaryContainer,
                depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                radius: 16,
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
          ],
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildMillionDollarsStep(ColorScheme cs, TextTheme tt) {
    return Column(
      key: const ValueKey('million_dollars_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        Image.asset(
          'assets/photos/elements/money-bag_1f4b0.webp',
          height: 120,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 24),
        Text(
          "First, take a gentle breath and imagine...",
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          "If someone offered you 10 million dollars right now, would you take it?",
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.8),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(flex: 1),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: DuoButton(
                onPressed: _handleBack,
                backgroundColor: cs.secondaryContainer,
                depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                radius: 16,
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
                onPressed: () {
                  HapticFeedback.lightImpact();
                  AnalyticsService.instance.logEvent('onboarding_million_dollars');
                  setState(() => _stepIndex = 2);
                },
                backgroundColor: cs.primary,
                depthColor: cs.primary.withValues(alpha: 0.8),
                radius: 16,
                sfxType: DuoSfxType.positive,
                child: Text(
                  "Yeah!",
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
    );
  }

  Widget _buildWakeUpStep(ColorScheme cs, TextTheme tt) {
    return Column(
      key: const ValueKey('wakeup_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        Image.asset(
          'assets/photos/elements/hourglass-done_231b.webp',
          height: 120,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 24),
        Text(
          "There's one catch though...",
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          "You don't get to wake up tomorrow morning. Your time here ends tonight. The 10 million is yours \u2014 but so is that.\n\nWould you still take it?",
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.8),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(flex: 1),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: DuoButton(
                onPressed: _handleBack,
                backgroundColor: cs.secondaryContainer,
                depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                radius: 16,
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
                onPressed: () {
                  HapticFeedback.lightImpact();
                  AnalyticsService.instance.logEvent('onboarding_wakeup_choice');
                  setState(() => _stepIndex = 3);
                },
                backgroundColor: cs.primary,
                depthColor: cs.primary.withValues(alpha: 0.8),
                radius: 16,
                sfxType: DuoSfxType.positive,
                child: Text(
                  "Nah!",
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
    );
  }

  Widget _buildConclusionStep(ColorScheme cs, TextTheme tt) {
    final name = widget.data.displayName ?? 'friend';
    return Column(
      key: const ValueKey('conclusion_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        Text(
          "Exactly!",
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          "Waking up tomorrow is worth more than 10 million dollars!\n\nStarting today $name, We'll try to make the most of every single day. Spend each one mindfully. Journal what's in your heart, here. Nurturing the good in you. Not letting the bitter in you grow, Reflecting on it before Allah.\n\nThis is your promise \u2014 to yourself and to Allah.",
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.8),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        CommitmentButton(
          onCommit: () {
            HapticFeedback.mediumImpact();
            AnalyticsService.instance.logEvent('onboarding_commitment_made');
            setState(() => _stepIndex = 4);
          },
          color: AppTheme.starGold,
          size: 144,
        ),
        const Spacer(flex: 1),
        Row(
          children: [
            Expanded(
              child: DuoButton(
                onPressed: _handleBack,
                backgroundColor: cs.secondaryContainer,
                depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                radius: 16,
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
          ],
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildPhoneHoursStep(ColorScheme cs, TextTheme tt) {
    return Column(
      key: const ValueKey('phone_hours_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        Text(
          "How many hours do you spend on your phone daily${widget.data.displayName != null ? " ${widget.data.displayName}" : ""}?",
          style: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          "${_phoneHours.toInt()} hrs/day",
          style: tt.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: _phoneHours,
          min: 0,
          max: 16,
          divisions: 16,
          onChanged: (v) => setState(() => _phoneHours = v),
        ),
        const Spacer(flex: 1),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: DuoButton(
                onPressed: _handleBack,
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
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.data.age = _age;
                  widget.data.phoneHours = _phoneHours.toInt();
                  AnalyticsService.instance.logEvent('onboarding_age_set', params: {'age': _age.toString()});
                  AnalyticsService.instance.logEvent('onboarding_phone_hours', params: {'hours': _phoneHours.toInt().toString()});
                  widget.onNext();
                },
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
    );
  }
}
