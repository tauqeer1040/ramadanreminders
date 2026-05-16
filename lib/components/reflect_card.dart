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
        color: cs.surfaceContainerHigh,
        image: frameImageAsset != null
            ? DecorationImage(
                image: AssetImage(frameImageAsset!),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                opacity: 0.18,
              )
            : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.surfaceContainerHigh,
            cs.surfaceContainer,
            cs.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.4),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.15),
            blurRadius: 22,
            spreadRadius: 3,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                image: frameImageAsset != null
                    ? DecorationImage(
                        image: AssetImage(frameImageAsset!),
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        opacity: 0.1,
                      )
                    : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.18),
                  width: 2,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SingleChildScrollView(child: child),
              ),
            ),
          ),
          if (showPlayButton)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
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
