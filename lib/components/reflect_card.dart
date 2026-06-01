import 'package:flutter/material.dart';
import 'wavy_play_button.dart';

class ReflectCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPlay;
  final bool isPlaying;
  final double playbackProgress;
  final bool showPlayButton;
  final Color backgroundColor;
  final Color borderColor;
  final Color? playButtonColor;

  const ReflectCard({
    super.key,
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.onPlay,
    this.isPlaying = false,
    this.playbackProgress = 0.0,
    this.showPlayButton = false,
    this.playButtonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor, width: 2),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(child: child),
          ),
          if (showPlayButton)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 4),
              child: Center(
                child: WavyPlayButton(
                  isPlaying: isPlaying,
                  progress: playbackProgress,
                  onTap: onPlay ?? () {},
                  color: playButtonColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
