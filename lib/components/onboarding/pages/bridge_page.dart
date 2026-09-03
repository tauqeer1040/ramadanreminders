import 'package:flutter/material.dart';
import '../onboarding_data.dart';
import '../../widgets/duo_button.dart';
import '../../../theme/app_theme.dart';

class BridgePage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BridgePage({
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
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                          fontSize: 32,
                        ),
                        children: [
                          const TextSpan(text: "Your Life"),
                          const TextSpan(text: "\n+\n"),
                          const TextSpan(text: "The Holy Quran,\n"),
                          const TextSpan(
                            text: "finally connected!",
                            style: TextStyle(color: AppTheme.starGold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Most people will keep reading without understanding. You won't. Here's how it works. Make your bed. Write one thought. Go to sleep. By morning, a Quran verse that speaks to your exact situation is waiting. That's the routine. 30 nights. No thinking required.",
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
                                  "Start writing",
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
