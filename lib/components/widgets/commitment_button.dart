import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_confetti/flutter_confetti.dart';

class CommitmentButton extends StatefulWidget {
  final VoidCallback onCommit;
  final Color color;
  final double size;

  const CommitmentButton({
    super.key,
    required this.onCommit,
    this.color = const Color(0xFFFACC15),
    this.size = 144,
  });

  @override
  State<CommitmentButton> createState() => _CommitmentButtonState();
}

class _CommitmentButtonState extends State<CommitmentButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHolding = false;
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _controller.addListener(() => setState(() {}));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isHolding) {
        _isComplete = true;
        HapticFeedback.heavyImpact();
        HapticFeedback.mediumImpact();
        Confetti.launch(
          context,
          options: ConfettiOptions(
            particleCount: 80,
            spread: 80,
            y: 0.5,
            scalar: 1.5,
            colors: const [
              Color(0xFF22C55E),
              Color(0xFFFACC15),
              Color(0xFFF4A6B8),
              Color(0xFF81D4FA),
              Color(0xFFA78BFA),
            ],
          ),
        );
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) widget.onCommit();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startHold() {
    if (_isComplete || _isHolding) return;
    _isHolding = true;
    _controller.forward();
  }

  void _cancelHold() {
    if (_isComplete) return;
    _isHolding = false;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _controller.value;
    final isComplete = _isComplete;

    return Listener(
      onPointerDown: (_) => _startHold(),
      onPointerUp: (_) => _cancelHold(),
      onPointerCancel: (_) => _cancelHold(),
      child: AnimatedScale(
        scale: isComplete ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.elasticOut,
        child: AnimatedOpacity(
          opacity: isComplete ? 0.8 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _WaterFillPainter(
                progress: progress,
                fillColor: widget.color,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
              ),
              child: Center(
                child: isComplete
                    ? _buildCheckmark()
                    : _buildFingerprint(progress),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckmark() {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF22C55E).withValues(alpha: 0.5),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
    );
  }

  Widget _buildFingerprint(double progress) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.fingerprint, color: widget.color, size: 72),
        const SizedBox(height: 4),
        Text(
          "Hold",
          style: TextStyle(
            color: widget.color.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _WaterFillPainter extends CustomPainter {
  final double progress;
  final Color fillColor;
  final Color backgroundColor;

  _WaterFillPainter({
    required this.progress,
    required this.fillColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final borderWidth = 3.0;
    final innerRadius = radius - borderWidth;

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: innerRadius)),
    );

    if (progress > 0) {
      final waterTop = size.height * (1 - progress);

      final waterPath = Path();
      waterPath.moveTo(0, size.height);
      waterPath.lineTo(0, waterTop);

      final waveLength = size.width / 3;
      final amplitude = 3.0;
      final steps = (size.width / 1).ceil();
      for (int i = 0; i <= steps; i++) {
        final x = (i / steps) * size.width;
        final waveY =
            waterTop +
            math.sin((x / waveLength) * 2 * math.pi + progress * 2 * math.pi) *
                amplitude;
        waterPath.lineTo(x, waveY);
      }

      waterPath.lineTo(size.width, size.height);
      waterPath.close();

      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          fillColor.withValues(alpha: 0.9),
          fillColor.withValues(alpha: 0.3),
        ],
      );

      final fillPaint = Paint()
        ..shader =
            gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(waterPath, fillPaint);
    }

    canvas.restore();

    final borderPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawCircle(center, innerRadius, borderPaint);

    if (progress > 0 && progress < 1) {
      final arcPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth + 2
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaterFillPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.fillColor != fillColor;
  }
}
