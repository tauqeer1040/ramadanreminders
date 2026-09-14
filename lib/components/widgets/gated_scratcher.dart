import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Blurred teaser for locked scratch-card content. The image renders clear
/// by default ([blurSigma] = 0); the lock badge marks it as gated.
/// Tapping fires [onUnlockTap] so the caller can present the paywall.
/// Used on the expired-trial wall to turn the scratch deck (the MVP) into
/// conversion fuel.
class GatedScratcher extends StatelessWidget {
  final String imageUrl;
  final VoidCallback? onUnlockTap;
  final double blurSigma;

  /// When false, the lock badge + dim are hidden and the face shows clear.
  /// Used by the thank-you (welcome) sheet — same 3 faces, no lock.
  final bool showLock;

  const GatedScratcher({
    super.key,
    required this.imageUrl,
    this.onUnlockTap,
    this.blurSigma = 0,
    this.showLock = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onUnlockTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: Image.asset(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.white.withValues(alpha: 0.05),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white24,
                    size: 28,
                  ),
                ),
              ),
            ),
            if (showLock)
              Container(color: Colors.black.withValues(alpha: 0.35)),
            if (showLock)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      color: AppTheme.starGold,
                      size: 26,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'MAX',
                      style: TextStyle(
                        color: AppTheme.starGold,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
