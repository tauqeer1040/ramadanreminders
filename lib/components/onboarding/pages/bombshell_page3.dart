import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import '../../widgets/duo_button.dart';
import '../../../theme/app_theme.dart';

class BombshellPage3 extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BombshellPage3({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
                      'assets/photos/mascot/reading.png',
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                          fontSize: 32,
                        ),
                        children: [
                          const TextSpan(
                            text: "With Meowmin, You could be reading\n",
                          ),
                          const TextSpan(
                            text: '300% more Quran\n',
                            style: TextStyle(color: AppTheme.starGold),
                          ),
                          const TextSpan(text: "in just \n"),
                          const TextSpan(
                            text: '2 minutes a day.',
                            style: TextStyle(color: AppTheme.starGold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Spend just 1 minute a day writing your diary, and 1 minute reading verses and stories from the Quran related to what you journal about. It\u2019s a practical start that naturally gets you reflecting on your day through the Quran far more than before.',
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
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
                                  "Let's do this",
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
