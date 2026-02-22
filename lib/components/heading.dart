// header.dart
import 'package:flutter/material.dart';

class RamadanHeader extends StatelessWidget {
  final int ramadanDay;
  final String monthName;

  const RamadanHeader({
    super.key,
    this.ramadanDay = 15,
    this.monthName = 'Ramadan',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          // Title row with icons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.nightlight_round,
                size: 32,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primaryContainer,
                      ],
                    ).createShader(bounds),
                    child: Text(
                      'Ramadan Journal',
                      style: textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Crimson Text',
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.auto_awesome,
                size: 24,
                color: colorScheme.primary.withValues(alpha: 0.6),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            'A sacred space for reflection & growth',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Space Grotesk',
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),

          // Day counter badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Day',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$ramadanDay',
                  style: TextStyle(
                    fontSize: 20,
                    fontFamily: 'Crimson Text',
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'of $monthName',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
