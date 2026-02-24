import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model/dhikr_item.dart';

/// Minimal display card — centered Arabic + transliteration only.
/// Numbers and progress bar are intentionally omitted.
class DhikrCard extends StatelessWidget {
  const DhikrCard({
    super.key,
    required this.item,
    required this.isActive,
    required this.onLongPress,
  });

  final DhikrItem item;
  final bool isActive;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isComplete = item.count >= item.target;

    final bg = isComplete
        ? colorScheme.secondaryContainer
        : colorScheme.primaryContainer;
    final borderColor = isComplete
        ? colorScheme.secondary
        : colorScheme.primary;
    final onBg = isComplete
        ? colorScheme.onSecondaryContainer
        : colorScheme.onPrimaryContainer;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isActive ? borderColor : borderColor.withValues(alpha: 0.2),
            width: isActive ? 3.5 : 0,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: borderColor.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: ConstrainedBox(
                  // Constrain width so text can naturally wrap into multiple lines
                  // instead of forcing a single unbounded line when inside FittedBox.
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth > 32
                        ? constraints.maxWidth - 32
                        : constraints.maxWidth,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Arabic ──────────────────────────────────────────────────
                      Text(
                        item.arabic,
                        textAlign: TextAlign.center,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.displaySmall?.copyWith(
                          color: borderColor,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                          fontFamily: 'Amiri',
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ── Transliteration ─────────────────────────────────────────
                      Text(
                        item.name,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          color: onBg.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
