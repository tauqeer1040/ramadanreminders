import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Gamey star trail: exactly 5 stars arc from [start] to [end] along a
/// half-parabola, staggered. [onStarArrived] fires once per star as it
/// lands so the score can tick up live with each arrival.
class StarTrailWidget extends StatefulWidget {
  final Offset start;
  final Offset end;
  final AnimationController controller;
  final void Function(int index)? onStarArrived;

  const StarTrailWidget({
    required this.start,
    required this.end,
    required this.controller,
    this.onStarArrived,
    super.key,
  });

  @override
  State<StarTrailWidget> createState() => _StarTrailWidgetState();
}

class _StarTrailWidgetState extends State<StarTrailWidget> {
  static const int starCount = 5;
  static const double _flight = 0.6;
  static const double _launchGap = 0.08;

  final Set<int> _arrived = {};
  late final List<_StarParticle> _stars;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _stars = List.generate(starCount, (i) {
      return _StarParticle(
        launchAt: i * _launchGap,
        lateral: Offset(
          (rng.nextDouble() - 0.5) * 28,
          (rng.nextDouble() - 0.5) * 28,
        ),
        size: 22.0 - i * 1.5,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final progress = widget.controller.value;
        if (progress <= 0.0 && _arrived.isNotEmpty) {
          _arrived.clear();
        }
        final p0 = widget.start;
        final p3 = widget.end;
        // Half-parabola: bow out sideways, land from below-ish.
        final bow = Offset(-(p3.dx - p0.dx) * 0.15 - 50, 60);
        final cp1 = Offset.lerp(p0, p3, 0.25)! + bow;
        final cp2 = Offset.lerp(p0, p3, 0.75)! + bow;

        return Stack(
          clipBehavior: Clip.none,
          children: _stars.asMap().entries.map((entry) {
            final i = entry.key;
            final p = entry.value;
            final raw = ((progress - p.launchAt) / _flight).clamp(0.0, 1.0);
            final tCurve = Curves.easeInOut.transform(raw);
            if (progress >= p.launchAt + _flight &&
                _arrived.add(i)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                widget.onStarArrived?.call(i);
              });
            }

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
                opacity: opacity * (raw <= 0 ? 0 : 1),
                child: Icon(
                  Icons.star_rounded,
                  color: AppTheme.starGold,
                  size: p.size,
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
  final double launchAt;
  final Offset lateral;
  final double size;

  const _StarParticle({
    required this.launchAt,
    required this.lateral,
    required this.size,
  });
}
