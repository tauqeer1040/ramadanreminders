import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import '../../widgets/duo_button.dart';
import '../../../theme/app_theme.dart';

class BombshellPage1 extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BombshellPage1({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final phoneHours = data.phoneHours ?? 4;
    final yearlyHours = phoneHours * 365;
    final yearlyDays = yearlyHours / 24;
    final name = data.displayName;

    final String timeLabel;
    if (yearlyDays >= 365) {
      final yrs = (yearlyDays / 365).toStringAsFixed(1);
      timeLabel = '$yrs years';
    } else if (yearlyDays >= 30) {
      final months = (yearlyDays / 30).round();
      timeLabel = '$months months';
    } else {
      timeLabel = '${yearlyDays.round()} days';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 32),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/photos/elements/exploding-head_1f92f.webp',
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                        children: [
                          if (name != null) TextSpan(text: '$name, '),
                          const TextSpan(text: 'You spend the equivalent of\n'),
                          TextSpan(
                            text: '$timeLabel a year',
                            style: const TextStyle(
                              color: AppTheme.starGold,
                              fontSize: 40,
                            ),
                          ),
                          const TextSpan(text: '\n nonstop on your phone.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'non-stop. back to back. every year.',
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: DuoButton(
                            onPressed: onBack,
                            backgroundColor: cs.secondaryContainer,
                            depthColor: cs.secondaryContainer.withValues(
                              alpha: 0.8,
                            ),
                            radius: 16,
                            height: 56,
                            sfxType: DuoSfxType.negative,
                            child: Text(
                              'Back',
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
                            onPressed: onNext,
                            backgroundColor: cs.primary,
                            depthColor: cs.primary.withValues(alpha: 0.8),
                            radius: 16,
                            height: 56,
                            sfxType: DuoSfxType.positive,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue',
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
