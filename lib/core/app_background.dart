import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final String? backgroundImage;
  final double overlayOpacity;

  const AppBackground({
    required this.child,
    this.backgroundImage,
    this.overlayOpacity = 0.20,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            backgroundImage ?? 'assets/photos/elements/app_bg2.webp',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: overlayOpacity),
          ),
        ),
        child,
      ],
    );
  }
}
