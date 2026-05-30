import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class DuoProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final double radius;
  final Color trackColor;
  final Color fillColor;

  const DuoProgressBar({
    super.key,
    required this.progress,
    this.height = 16.0,
    this.radius = 20.0,
    this.trackColor = const Color(0xFF3C3C3C),
    this.fillColor = AppTheme.neonPurple,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        children: [
          // Fill Layer
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.neonPurple, AppTheme.neonPurple.withValues(alpha: 0.7)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(radius),
              ),
              child: Stack(
                children: [
                  // Glass/Glimmer Highlight
                  Positioned(
                    top: 2,
                    left: 4,
                    right: 4,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(radius),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
