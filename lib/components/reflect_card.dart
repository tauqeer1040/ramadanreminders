import 'package:flutter/material.dart';
import 'wavy_play_button.dart';

class ReflectCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPlay;
  final bool isPlaying;
  final double playbackProgress;
  final bool showPlayButton;
  final String? frameImageAsset;

  const ReflectCard({
    super.key,
    required this.child,
    this.onPlay,
    this.isPlaying = false,
    this.playbackProgress = 0.0,
    this.showPlayButton = false,
    this.frameImageAsset,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        image: frameImageAsset != null
            ? DecorationImage(
                image: AssetImage(frameImageAsset!),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                opacity: 0.2,
              )
            : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surface.withValues(alpha: 0.86),
            cs.surfaceContainerHigh.withValues(alpha: 0.78),
            cs.surface.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.5),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.18),
            blurRadius: 22,
            spreadRadius: 3,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.76),
                image: frameImageAsset != null
                    ? DecorationImage(
                        image: AssetImage(frameImageAsset!),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        opacity: 0.14,
                      )
                    : null,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    cs.surface.withValues(alpha: 0.38),
                    cs.surfaceContainerHighest.withValues(alpha: 0.72),
                    cs.surface.withValues(alpha: 0.44),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.22),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
          if (showPlayButton)
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Center(
                child: WavyPlayButton(
                  isPlaying: isPlaying,
                  progress: playbackProgress,
                  onTap: onPlay ?? () {},
                ),
              ),
            ),
        ],
      ),
    );
  }
}
