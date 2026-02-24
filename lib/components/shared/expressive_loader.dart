import 'dart:math' as math;
import 'package:flutter/material.dart';

class ExpressiveLoader extends StatefulWidget {
  const ExpressiveLoader({super.key});

  @override
  State<ExpressiveLoader> createState() => _ExpressiveLoaderState();
}

class _ExpressiveLoaderState extends State<ExpressiveLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final angle = t * 2 * math.pi;

        // Morphing border radii for an M3-expressive blob shape
        final r1 = 30.0 + 15.0 * math.sin(t * 3 * math.pi);
        final r2 = 30.0 + 15.0 * math.cos(t * 2 * math.pi);
        final r3 = 30.0 + 15.0 * math.sin(t * 4 * math.pi);
        final r4 = 30.0 + 15.0 * math.cos(t * 5 * math.pi);

        return Transform.rotate(
          angle: angle,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              border: Border.all(color: colorScheme.primary, width: 4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(r1),
                topRight: Radius.circular(r2),
                bottomRight: Radius.circular(r3),
                bottomLeft: Radius.circular(r4),
              ),
            ),
            child: Center(
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
