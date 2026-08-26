import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'deferred_lottie.dart';

class StarBadge extends StatelessWidget {
  final int streakCount;
  final int totalStars;
  final bool showStreak;
  final Animation<double> starScaleAnim;

  const StarBadge({
    super.key,
    required this.streakCount,
    required this.totalStars,
    required this.showStreak,
    required this.starScaleAnim,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      width: 72,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (child, animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: showStreak
            ? Column(
                key: const ValueKey('streak'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: DeferredLottie(
                      asset: 'assets/photos/elements/streak_fire.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$streakCount',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                ],
              )
            : Column(
                key: const ValueKey('stars'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: starScaleAnim,
                    child: const Icon(Icons.star_rounded, color: AppTheme.starGold, size: 28),
                  ),
                  const SizedBox(height: 2),
                  ScaleTransition(
                    scale: starScaleAnim,
                    child: Text(
                      '$totalStars',
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.starGold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
