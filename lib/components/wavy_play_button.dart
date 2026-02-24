import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WavyPlayButton extends StatefulWidget {
  const WavyPlayButton({
    super.key,
    required this.isPlaying,
    required this.onTap,
    this.progress = 0.0,
  });

  final bool isPlaying;
  final VoidCallback onTap;
  final double progress;

  @override
  State<WavyPlayButton> createState() => _WavyPlayButtonState();
}

class _WavyPlayButtonState extends State<WavyPlayButton> {
  int _tapCounter = 0;

  void _handleTap() {
    HapticFeedback.heavyImpact();
    setState(() {
      _tapCounter++;
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fillColor = colorScheme.primaryContainer;
    final outlineColor = colorScheme.primaryContainer;
    final iconColor = colorScheme.onPrimaryContainer;
    final progressColor = colorScheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _handleTap,
      child: SizedBox(
        width: 100,
        height: 100,
        child:
            Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer wavy progress outline
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CustomPaint(
                        painter: _WavyPainter(
                          color: outlineColor,
                          isOutline: true,
                          strokeWidth: 4.0,
                          progressColor: widget.isPlaying
                              ? progressColor
                              : outlineColor,
                          // If playing, we can show a full or animated progress.
                          // For now we'll just show a static 20% progress like the image,
                          // or animate it continuously if playing.
                          // Since we don't have exact progress, we can just style a highlight.
                          progress: widget.progress,
                        ),
                      ),
                    ),
                    // Inner wavy solid shape
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CustomPaint(
                        painter: _WavyPainter(
                          color: fillColor,
                          isOutline: false,
                        ),
                      ),
                    ),
                    // Icon
                    Icon(
                      widget.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: iconColor,
                      size: 40,
                    ),
                  ],
                )
                .animate(key: ValueKey('${_tapCounter}_${widget.isPlaying}'))
                .scale(
                  begin: const Offset(1.2, 1.2),
                  end: const Offset(1.0, 1.0),
                  duration: 400.ms,
                  curve: Curves.elasticOut,
                ),
      ),
    );
  }
}

class _WavyPainter extends CustomPainter {
  final Color color;
  final bool isOutline;
  final double strokeWidth;
  final Color? progressColor;
  final double progress;

  _WavyPainter({
    required this.color,
    this.isOutline = false,
    this.strokeWidth = 3.0,
    this.progressColor,
    this.progress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final R = size.width / 2.0 - (isOutline ? strokeWidth : 0);

    final a = size.width * 0.035; // wave amplitude
    final n = 8; // number of scallops (expressive M3 shape)

    final path = Path();
    for (int i = 0; i <= 360; i += 2) {
      final theta = i * math.pi / 180;
      // offset theta so top is aligned nicely
      final offsetTheta = theta - math.pi / 2;
      final currentR = R - a + a * math.sin(n * offsetTheta);
      final x = center.dx + currentR * math.cos(offsetTheta);
      final y = center.dy + currentR * math.sin(offsetTheta);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    if (isOutline) {
      final bgPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, bgPaint);

      if (progress > 0 && progressColor != null) {
        // Draw the progress segment using PathMetrics
        final metrics = path.computeMetrics().toList();
        if (metrics.isNotEmpty) {
          final metric = metrics.first;
          final extractPath = metric.extractPath(0, metric.length * progress);
          final progressPaint = Paint()
            ..color = progressColor!
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth + 1
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round;
          canvas.drawPath(extractPath, progressPaint);
        }
      }
    } else {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavyPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isOutline != isOutline ||
        oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}
