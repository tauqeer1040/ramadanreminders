import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'emotion_flower_painter.dart';
import 'emotion_theme.dart';

class EmotionFlower extends StatefulWidget {
  final double sliderValue;
  final double compactSize;

  const EmotionFlower({super.key, required this.sliderValue, this.compactSize = 260});

  @override
  State<EmotionFlower> createState() => _EmotionFlowerState();
}

class _EmotionFlowerState extends State<EmotionFlower>
    with TickerProviderStateMixin {
  late final AnimationController _breathCtrl;
  late final AnimationController _timeCtrl;
  late final AnimationController _responseCtrl;
  late final AnimationController _rotateCtrl;
  late final Animation<double> _breathAnim;
  late final Animation<double> _rotateAnim;
  late final Listenable _merged;

  @override
  void initState() {
    super.initState();

    _breathCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _breathAnim = Tween<double>(begin: 0.98, end: 1.03).animate(
      CurvedAnimation(parent: _breathCtrl, curve: Curves.easeInOut),
    );

    _timeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();

    _responseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();

    _rotateAnim = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(parent: _rotateCtrl, curve: Curves.linear),
    );

    _merged = Listenable.merge([_breathCtrl, _timeCtrl, _responseCtrl, _rotateCtrl]);
  }

  @override
  void didUpdateWidget(EmotionFlower old) {
    super.didUpdateWidget(old);
    if (widget.sliderValue != old.sliderValue) {
      _responseCtrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _breathCtrl.dispose();
    _timeCtrl.dispose();
    _responseCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = EmotionTheme.lerp(widget.sliderValue);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _merged,
        builder: (_, __) {
          final raw = _responseCtrl.value;
          final eased = Curves.easeOut.transform(raw);
          final responseDecay = 1.0 - eased;

          return Transform.rotate(
            angle: _rotateAnim.value * pi,
            alignment: Alignment.center,
            child: CustomPaint(
              size: Size.square(widget.compactSize),
              painter: EmotionFlowerPainter(
                animTime: _timeCtrl.value * 120.0,
                breathScale: _breathAnim.value,
                petalColor: colors.petalColor,
                glowColor: colors.glowColor,
                sliderValue: widget.sliderValue,
                responseValue: responseDecay,
              ),
            ),
          );
        },
      ),
    );
  }
}
