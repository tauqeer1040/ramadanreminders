import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A glassmorphism container that renders a blur backdrop on native platforms
/// (which use the CanvasKit renderer and fully support `BackdropFilter`), but
/// falls back to a flat semi-transparent surface on the web HTML renderer where
/// `BackdropFilter` is not supported. This lets us ship the much lighter HTML
/// renderer for dramatically faster load times without breaking the visual
/// design — the frosted-glass blur degrades gracefully to a solid tint.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double sigmaX;
  final double sigmaY;
  final Color tint;
  final BorderRadiusGeometry? borderRadius;
  final Border? border;
  final EdgeInsetsGeometry? padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.sigmaX = 10,
    this.sigmaY = 10,
    this.tint = const Color(0xFFFFFFFF),
    this.borderRadius,
    this.border,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20);

    if (kIsWeb) {
      // HTML renderer: no blur support. Use a flat translucent surface.
      return ClipRRect(
        borderRadius: radius,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            border: border,
            borderRadius: radius,
          ),
          child: child,
        ),
      );
    }

    // Native (CanvasKit): full frosted-glass effect.
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint,
            border: border,
            borderRadius: radius,
          ),
          child: child,
        ),
      ),
    );
  }
}
