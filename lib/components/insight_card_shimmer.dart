import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import './reflect_card.dart';

/// A Skeletonizer-based shimmer that perfectly mirrors the shape of a ReflectCard.
class InsightCardShimmer extends StatelessWidget {
  const InsightCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Skeletonizer(
      enabled: true,
      child: ReflectCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Loading AI Insights...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                Chip(label: const Text('TAGS')),
                Chip(label: const Text('LOADING')),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Loading personalized reflection just for you...',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Fetching the latest journal entries and processing through our AI models. This may take a few seconds during first load. SubhanAllah, your spiritual journey is being analyzed.',
              style: textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Searching for the perfect verse to match your current state of heart...',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('Surah : Ayah'),
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
