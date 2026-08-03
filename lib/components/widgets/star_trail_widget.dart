import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class StarTrailWidget extends StatelessWidget {
  final Offset start;
  final Offset end;
  final AnimationController controller;

  const StarTrailWidget({
    required this.start,
    required this.end,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final rng = Random();
    final stars = List.generate(18, (i) {
      final t = i / 18;
      final delay = t * 0.25;
      final lateral = Offset(
        (rng.nextDouble() - 0.5) * 24,
        (rng.nextDouble() - 0.5) * 24,
      );
      return _StarParticle(
        delay: delay,
        lateral: lateral,
      );
    });

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final progress = controller.value;
        return Stack(
          children: stars.map((p) {
            final p0 = start;
            final p3 = end;
            final cp1 = Offset(p0.dx + 40, p0.dy + 100);
            final cp2 = Offset(p3.dx - 80, p3.dy + 160);

            final raw = (progress - p.delay).clamp(0.0, 1.0) / (1 - p.delay);
            final tCurve = Curves.easeInOut.transform(raw.clamp(0.0, 1.0));

            final pos = _cubicBezier(p0, cp1, cp2, p3, tCurve) + p.lateral;

            final opacity = (tCurve < 0.1)
                ? tCurve / 0.1
                : (tCurve > 0.85)
                    ? (1 - tCurve) / 0.15
                    : 1.0;

            return Positioned(
              left: pos.dx - 10,
              top: pos.dy - 10,
              child: Opacity(
                opacity: opacity * (raw < 0 ? 0 : 1),
                child: Icon(
                  Icons.star_rounded,
                  color: AppTheme.starGold,
                  size: 20,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Offset _cubicBezier(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final mt = 1 - t;
    return p0 * (mt * mt * mt) +
        p1 * (3 * mt * mt * t) +
        p2 * (3 * mt * t * t) +
        p3 * (t * t * t);
  }
}

class _StarParticle {
  final double delay;
  final Offset lateral;

  const _StarParticle({required this.delay, required this.lateral});
}
