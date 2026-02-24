import 'package:flutter/material.dart';

class BouncingWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const BouncingWidget({super.key, required this.child, this.onPressed});

  @override
  State<BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null) setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = false);
      widget.onPressed?.call();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    // Determine the scale based on the pressed state.
    final scale = _isPressed ? 0.90 : 1.0;

    // Choose the animation curve:
    // When released (springing back out), we use elasticOut for that bouncy "balloon" pop effect.
    // When pressed, a smooth easeOut feels natural.
    final curve = _isPressed ? Curves.easeOut : Curves.elasticOut;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 150),
        curve: curve,
        child: widget.child,
      ),
    );
  }
}
