import 'dart:math';
import 'package:flutter/material.dart';

class EmotionFlowerPainter extends CustomPainter {
  final double animTime;
  final double breathScale;
  final Color petalColor;
  final Color glowColor;
  final double sliderValue;
  final double responseValue;

  final double _points;
  final double _innerRadiusRatio;
  final double _pointRounding;
  final double _valleyRounding;

  static const List<double> _radii     = [0.86, 0.76, 0.65, 0.53, 0.40, 0.25];
  static const List<double> _opacities = [0.15, 0.30, 0.45, 0.65, 0.85, 1.00];
  static const List<double> _phases    = [0.000, 1.047, 2.094, 3.142, 4.189, 5.236];

  static const List<List<double>> _keyframes = [
    // [points, innerRadiusRatio, pointRounding, valleyRounding]
    [12.0, 0.40, 0.05, 0.00], // 0.00 – Very Unpleasant (12 sharp points)
    [ 8.0, 0.45, 0.25, 0.10], // 0.25 – Unpleasant (8 points, wavy)
    [ 8.0, 0.60, 0.45, 0.45], // 0.50 – Neutral (smooth circular ripples)
    [ 5.0, 0.48, 0.50, 0.30], // 0.75 – Pleasant (5 points, somewhat rounded)
    [ 5.0, 0.40, 0.55, 0.40], // 1.00 – Very Pleasant (soft 5-petal flower, guaranteed visible)
  ];

  EmotionFlowerPainter({
    required this.animTime,
    required this.breathScale,
    required this.petalColor,
    required this.glowColor,
    required this.sliderValue,
    this.responseValue = 0.0,
  })  : _points           = _kf(sliderValue, 0),
        _innerRadiusRatio = _kf(sliderValue, 1),
        _pointRounding    = _kf(sliderValue, 2),
        _valleyRounding   = _kf(sliderValue, 3);

  static double _kf(double sv, int idx) {
    final t = sv.clamp(0.0, 1.0) * (_keyframes.length - 1);
    final lo = _keyframes[t.floor()];
    final hi = _keyframes[t.ceil()];
    final f = t - t.floor();
    return lo[idx] + (hi[idx] - lo[idx]) * f;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final maxR = size.shortestSide * 0.5;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);

    for (int i = 0; i < 6; i++) {
      final phase = _phases[i];

      // Traveling ripple effect across layers
      final ripplePhase = animTime * 1.5 - (i * 0.8);
      final layerBreath = breathScale + sin(ripplePhase) * 0.03;
      final irPulse = sin(ripplePhase * 1.2) * 0.04;
      final innerRatio = (_innerRadiusRatio + irPulse).clamp(0.10, 0.80);
      
      // Faster rotation
      final rotRad = animTime * 0.08 * (i.isEven ? 1.0 : -0.7) + (i * 0.4);

      final cascadeDelay = i * 0.08;
      final localResponse = responseValue > cascadeDelay
          ? (responseValue - cascadeDelay) / (1.0 - cascadeDelay)
          : 0.0;

      final responseScale = 1.0 + localResponse * 0.06 * (1.0 - i * 0.1).clamp(0.0, 1.0);
      final responseBrightness = localResponse * 0.5 * (1.0 - i * 0.08).clamp(0.0, 1.0);

      final r = maxR * _radii[i] * layerBreath * responseScale;

      // Enforce StarBorder constraint: sum of pointRounding and valleyRounding must not exceed 1.0
      double pRound = _pointRounding;
      double vRound = _valleyRounding;
      if (pRound + vRound > 0.98) {
        final scale = 0.98 / (pRound + vRound);
        pRound *= scale;
        vRound *= scale;
      }

      final star = StarBorder(
        points: _points,
        innerRadiusRatio: innerRatio,
        pointRounding: pRound,
        valleyRounding: vRound,
      );
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: r * 2,
        height: r * 2,
      );

      canvas.save();
      canvas.rotate(rotRad);

      final path = star.getOuterPath(rect);
      final baseOpacity = _opacities[i];
      final surgeOpacity = (baseOpacity + localResponse * 0.20).clamp(0.0, 1.0);
      
      // The images show petals that are slightly darker in the center and lighter at the edges
      final layerPetalColor = Color.lerp(
        petalColor,
        Colors.white,
        0.1 + (i * 0.08) + responseBrightness * 0.3,
      )!;

      // 1. Prominent drop shadow for 3D layered effect
      if (i > 0) {
        // Offset shadow slightly outwards
        final shadowPath = star.getOuterPath(
          Rect.fromCenter(
            center: Offset(0, maxR * 0.015), // Slight downward shift
            width: r * 2.05,
            height: r * 2.05,
          )
        );
        
        canvas.drawPath(
          shadowPath,
          Paint()
            ..color = petalColor.withValues(alpha: 0.25 + localResponse * 0.1)
            ..style = PaintingStyle.fill
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12.0 + localResponse * 8.0),
        );
      }

      // 2. Base Petal Fill (solid with radial depth gradient)
      final petalGradient = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Color.lerp(layerPetalColor, Colors.black, 0.15)!.withValues(alpha: surgeOpacity),
          layerPetalColor.withValues(alpha: surgeOpacity),
        ],
        stops: const [0.3, 1.0],
      );

      canvas.drawPath(
        path,
        Paint()
          ..shader = petalGradient.createShader(rect)
          ..style = PaintingStyle.fill,
      );

      // 3. Subtle inner highlight / edge sheen
      final edgeGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: (0.4 + localResponse * 0.2) * surgeOpacity),
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.0),
          Color.lerp(petalColor, Colors.black, 0.4)!.withValues(alpha: 0.2 * surgeOpacity),
        ],
      );

      canvas.drawPath(
        path,
        Paint()
          ..shader = edgeGradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      canvas.restore();
    }

    if (responseValue > 0) {
      final glowRadius = 20 + responseValue * 30;
      canvas.drawCircle(
        Offset.zero,
        glowRadius,
        Paint()
          ..color = glowColor.withValues(alpha: responseValue * 0.20)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius),
      );
    }

    canvas.drawCircle(
      Offset.zero,
      9,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      Offset.zero,
      3.5,
      Paint()..color = Colors.white.withValues(alpha: 0.70),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(EmotionFlowerPainter old) =>
      old.animTime != animTime ||
      old.breathScale != breathScale ||
      old.petalColor != petalColor ||
      old.glowColor != glowColor ||
      old.sliderValue != sliderValue ||
      old.responseValue != responseValue;
}
