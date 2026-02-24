import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A large ghost watermark showing [count] that doubles as a "tap to reset"
/// control.
class TapToResetWatermark extends StatefulWidget {
  const TapToResetWatermark({
    super.key,
    required this.count,
    required this.onReset,
  });

  final int count;
  final void Function(Offset) onReset;

  @override
  State<TapToResetWatermark> createState() => _TapToResetWatermarkState();
}

class _TapToResetWatermarkState extends State<TapToResetWatermark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Opacity: brightens as the scale grows to signal progress
  late final Animation<double> _opacity;

  bool _triggered = false;
  int _bounceCounter = 0;
  Offset _lastTapPosition = Offset.zero;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _opacity = Tween<double>(
      begin: 0.10,
      end: 0.65,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.addStatusListener(_onAnimationStatus);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_triggered) {
      _triggered = true;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _controller.reverse();
      });
    }
    if (status == AnimationStatus.dismissed) {
      _triggered = false;
    }
  }

  void _onTapDown(TapDownDetails details) {
    _lastTapPosition = details.globalPosition;
  }

  void _onTap() {
    if (_triggered) return;
    HapticFeedback.heavyImpact();
    widget.onReset(_lastTapPosition);
    setState(() {
      _bounceCounter++;
    });
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: _onTapDown,
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Text(
                '${widget.count}',
                style: textTheme.displayLarge?.copyWith(
                  fontSize: 160,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface.withValues(
                    alpha: _opacity.value,
                  ),
                  height: 1.0,
                  letterSpacing: -10,
                ),
              )
              .animate(
                key: ValueKey(
                  '${widget.count}_$_bounceCounter',
                ), // Reacts every time count changes OR if explicitly tapped
              )
              .scale(
                begin: const Offset(1.15, 1.15),
                end: const Offset(1.0, 1.0),
                duration: 400.ms,
                curve: Curves.elasticOut, // Spring physics
              );
        },
      ),
    );
  }
}
