import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:confetti/confetti.dart';

/// A minimal task card for the horizontal tasks carousel.
///
/// Tap toggles the completed state. Long-press triggers delete.
class TaskCard extends StatefulWidget {
  const TaskCard({
    super.key,
    required this.text,
    required this.completed,
    required this.isFocused,
    required this.onTap,
    required this.onFocus,
    required this.onDelete,
    required this.index,
    required this.bgImage,
  });

  final String text;
  final bool completed;
  final bool isFocused;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final VoidCallback onDelete;
  final int index;
  final String bgImage;

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.completed && !oldWidget.completed) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCentered = constraints.maxWidth > 160;
        final double textOpacity = isCentered ? 1.0 : 0.0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (isCentered) {
              widget.onTap();
            } else {
              widget.onFocus();
            }
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            widget.onDelete();
          },
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(widget.bgImage),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.25),
                  BlendMode.darken,
                ),
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: OverflowBox(
              alignment: Alignment.center,
              minWidth: 220,
              maxWidth: constraints.maxWidth > 220 ? constraints.maxWidth : 220,
              minHeight: constraints.maxHeight,
              maxHeight: constraints.maxHeight,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: textOpacity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The large centered typography
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        widget.text.toLowerCase(),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          textStyle: tt.displaySmall,
                          color: widget.completed
                              ? Colors.white70
                              : Colors.white,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1.0,
                          height: 1.1,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          decoration: widget.completed
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: Colors.white.withValues(alpha: 0.8),
                          decorationThickness: 1.5,
                        ),
                      ),
                    ),

                    // Confetti explosion behind/over the text
                    IgnorePointer(
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        shouldLoop: false,
                        emissionFrequency: 0.05,
                        numberOfParticles: 20,
                        colors: const [
                          Colors.white,
                          Colors.white70,
                          Colors.pinkAccent,
                          Colors.amberAccent,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
