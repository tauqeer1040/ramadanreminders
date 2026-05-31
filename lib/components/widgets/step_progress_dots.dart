import 'package:flutter/material.dart';

class StepProgressDots extends StatelessWidget {
  /// The total number of steps in the progression.
  final int totalSteps;

  /// The current step index (0-indexed).
  final int currentStep;

  /// The height of each progress dot/segment.
  final double height;

  /// The margin between adjacent dot segments.
  final double spacing;

  /// The color of the filled (active and completed) steps.
  /// Defaults to `Theme.of(context).colorScheme.primary`.
  final Color? activeColor;

  /// The color of the unfilled (inactive) steps.
  /// Defaults to `Theme.of(context).colorScheme.onSurface.withOpacity(0.2)`.
  final Color? inactiveColor;

  /// The border radius of each dot segment.
  /// Defaults to fully circular/capsule pills.
  final BorderRadiusGeometry? borderRadius;

  /// The duration of the transition animation when steps change.
  final Duration duration;

  /// The curve used for the transition animation.
  final Curve curve;

  /// Whether the currently active dot should expand horizontally
  /// to create a modern active-indicator style progress bar.
  final bool animateActiveWidth;

  const StepProgressDots({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.height = 6.0,
    this.spacing = 8.0,
    this.activeColor,
    this.inactiveColor,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.animateActiveWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final themeActiveColor = activeColor ?? Theme.of(context).colorScheme.primary;
    final themeInactiveColor = inactiveColor ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2);
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(height / 2);

    return Row(
      children: List.generate(
        totalSteps,
        (index) {
          final isCompletedOrActive = index <= currentStep;
          final isActive = index == currentStep;

          Widget dot = AnimatedContainer(
            duration: duration,
            curve: curve,
            height: height,
            decoration: BoxDecoration(
              color: isCompletedOrActive ? themeActiveColor : themeInactiveColor,
              borderRadius: effectiveBorderRadius,
            ),
          );

          if (animateActiveWidth) {
            return Expanded(
              flex: isActive ? 2 : 1,
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == totalSteps - 1 ? 0 : spacing,
                ),
                child: dot,
              ),
            );
          } else {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == totalSteps - 1 ? 0 : spacing,
                ),
                child: dot,
              ),
            );
          }
        },
      ),
    );
  }
}
