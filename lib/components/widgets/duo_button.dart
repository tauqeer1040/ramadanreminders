import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DuoButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color depthColor;
  final double height;
  final double radius;
  final Widget child;
  final bool dimOnDisabled;

  const DuoButton({
    super.key,
    required this.onPressed,
    required this.backgroundColor,
    required this.depthColor,
    required this.child,
    this.height = 52,
    this.radius = 12,
    this.dimOnDisabled = false,
  });

  @override
  State<DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<DuoButton> {
  bool _pressed = false;

  bool get _isDisabled => widget.onPressed == null;

  @override
  void didUpdateWidget(covariant DuoButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null && _pressed) {
      setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- ADJUST THESE TWO VALUES ---
    const double shadowHeight = 8.0; // The static thickness of the base
    final double travelDistance = _pressed ? shadowHeight : 0; // The movement depth
    // -------------------------------

    final bool isActuallyDisabled = _isDisabled && widget.dimOnDisabled;

    return Opacity(
      opacity: isActuallyDisabled ? 0.5 : 1.0,
      child: Listener(
        onPointerDown: _isDisabled
            ? null
            : (_) {
                HapticFeedback.lightImpact();
                setState(() => _pressed = true);
              },
        onPointerUp: (_) {
          if (mounted) {
            setState(() => _pressed = false);
            // Trigger the action on release for better UX and animation timing
            if (!_isDisabled && widget.onPressed != null) {
              widget.onPressed!();
            }
          }
        },
        onPointerCancel: (_) {
          if (mounted) setState(() => _pressed = false);
        },
        child: SizedBox(
          height: widget.height + shadowHeight,
          child: Stack(
            children: [
              // 1. THE BASE (The Shadow Part)
              // Pinned to the bottom of the stack
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: widget.depthColor,
                    borderRadius: BorderRadius.circular(widget.radius),
                  ),
                ),
              ),
              // 2. THE TOP (The Interactive Part)
              // This is what "slides" down to meet the base
              AnimatedPositioned(
                duration: const Duration(milliseconds: 60),
                top: travelDistance,
                left: 0,
                right: 0,
                child: Container(
                  height: widget.height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.backgroundColor,
                    borderRadius: BorderRadius.circular(widget.radius),
                  ),
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
