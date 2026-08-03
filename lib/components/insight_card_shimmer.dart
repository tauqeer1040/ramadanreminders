import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import './reflect_card.dart';

class InsightCardShimmer extends StatelessWidget {
  const InsightCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      enabled: true,
      child: ReflectCard(
        backgroundColor: cs.surfaceContainerHigh,
        borderColor: cs.primary.withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: Container(
                    width: 32,
                    height: 32,
                    color: cs.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reading your journal entry and reflecting on what you wrote...',
                    style: textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'A meaningful excerpt from your journal will appear here...',
                style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A Quranic verse will be waiting here for you...',
                    style: textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('— Surah : Ayah'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
