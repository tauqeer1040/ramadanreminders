import 'package:flutter/material.dart';
import 'duo_button.dart';

class OnboardingNavRow extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String? nextLabel;
  final bool showBack;

  const OnboardingNavRow({
    super.key,
    this.onBack,
    this.onNext,
    this.nextLabel,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (showBack && onBack != null)
          Expanded(
            flex: 1,
            child: DuoButton(
              onPressed: onBack,
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
        if (showBack && onBack != null) const SizedBox(width: 16),
        if (onNext != null)
          Expanded(
            flex: showBack ? 2 : 3,
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
                    nextLabel ?? "Continue",
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
    );
  }
}
