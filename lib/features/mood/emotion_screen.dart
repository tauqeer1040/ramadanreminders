import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'emotion_theme.dart';
import 'emotion_flower.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Reusable mood body (used by EmotionScreen and JournalBottomSheet morph)
// ─────────────────────────────────────────────────────────────────────────────

class MoodPanel extends StatelessWidget {
  final double sliderValue;
  final ValueChanged<double> onSliderChanged;
  final VoidCallback onDone;
  final double availableHeight;
  final double sheetWidth;
  final EdgeInsets padding;

  const MoodPanel({
    super.key,
    required this.sliderValue,
    required this.onSliderChanged,
    required this.onDone,
    required this.availableHeight,
    required this.sheetWidth,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    final colors = EmotionTheme.lerp(sliderValue);
    final isTight = availableHeight < 400;
    final flowerSz = (availableHeight * 0.32).clamp(80.0, 220.0);
    final labelSize = isTight ? 22.0 : 30.0;

    return Padding(
      padding: padding,
      child: SizedBox(
        width: sheetWidth - padding.left - padding.right,
        height: availableHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 2),
            SizedBox(
              width: 32,
              height: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 48,
              child: Stack(
                children: [
                  const Center(
                    child: Text(
                      'Emotion',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onDone,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.check_rounded,
                            size: 28,
                            color: colors.petalColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: EmotionFlower(sliderValue: sliderValue, compactSize: flowerSz),
              ),
            ),
            _CompactLabel(label: colors.label, fontSize: labelSize),
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: (sheetWidth - padding.left - padding.right) * 0.05),
              child: _CompactSlider(
                value: sliderValue,
                petalColor: colors.petalColor,
                onChanged: onSliderChanged,
                isTight: isTight,
              ),
            ),
            const SizedBox(height: 2),
            _CompactEndpointLabels(isTight: isTight),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen EmotionScreen (standalone bottom sheet)
// ─────────────────────────────────────────────────────────────────────────────

class EmotionScreen extends StatefulWidget {
  const EmotionScreen({super.key});

  @override
  State<EmotionScreen> createState() => _EmotionScreenState();
}

class _EmotionScreenState extends State<EmotionScreen>
    with SingleTickerProviderStateMixin {
  double _sliderValue = 0.5;

  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  void _onSliderChanged(double v) {
    HapticFeedback.selectionClick();
    setState(() => _sliderValue = v);
  }

  void _onNext() {
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop(
      EmotionEntry(value: _sliderValue, timestamp: DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = EmotionTheme.lerp(_sliderValue);
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final sheetH = (size.height * 0.38).clamp(310.0, 370.0) + bottomPadding;
    final sheetW = size.width;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(
          EmotionEntry(value: _sliderValue, timestamp: DateTime.now()),
        );
      },
      child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: SizedBox(
        height: sheetH,
        child: Stack(
          children: [
            _AnimatedBackground(bgCtrl: _bgCtrl, colors: colors),
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.08),
                    border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                  ),
                  child: SafeArea(
                    bottom: true,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return MoodPanel(
                          sliderValue: _sliderValue,
                          onSliderChanged: _onSliderChanged,
                          onDone: _onNext,
                          availableHeight: constraints.maxHeight,
                          sheetWidth: sheetW,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CompactLabel extends StatelessWidget {
  final String label;
  final double fontSize;
  const _CompactLabel({required this.label, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        ),
      ),
      child: Text(
        label,
        key: ValueKey(label),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _CompactSlider extends StatelessWidget {
  final double value;
  final Color petalColor;
  final ValueChanged<double> onChanged;
  final bool isTight;

  const _CompactSlider({
    required this.value,
    required this.petalColor,
    required this.onChanged,
    required this.isTight,
  });

  @override
  Widget build(BuildContext context) {
    final thumbR = isTight ? 8.0 : 10.0;
    final trackH = isTight ? 6.0 : 8.0;

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: trackH,
        trackShape: _PillTrackShape(),
        thumbShape: _ShadowedThumbShape(radius: thumbR),
        activeTrackColor: petalColor,
        inactiveTrackColor: petalColor.withValues(alpha: 0.20),
        thumbColor: petalColor.withValues(alpha: 0.85),
        overlayColor: petalColor.withValues(alpha: 0.12),
        overlayShape: RoundSliderOverlayShape(overlayRadius: thumbR + 4),
      ),
      child: Slider(
        value: value,
        min: 0.0,
        max: 1.0,
        onChanged: onChanged,
      ),
    );
  }
}

class _CompactEndpointLabels extends StatelessWidget {
  final bool isTight;
  const _CompactEndpointLabels({required this.isTight});

  @override
  Widget build(BuildContext context) {
    if (isTight) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('VERY UNPLEASANT', style: _labelStyle(isTight)),
          Text('VERY PLEASANT',   style: _labelStyle(isTight)),
        ],
      ),
    );
  }

  static TextStyle _labelStyle(bool isTight) => TextStyle(
    fontSize: isTight ? 8 : 11,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    letterSpacing: 0.3,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated background
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedBackground extends StatelessWidget {
  final AnimationController bgCtrl;
  final EmotionColors colors;

  const _AnimatedBackground({required this.bgCtrl, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: bgCtrl,
      builder: (_, __) {
        final shift = bgCtrl.value;
        final bottomColor = Color.lerp(colors.bgBottom, colors.bgMid, shift * 0.06)!;

        return Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                bottomColor.withValues(alpha: 0.0),
                bottomColor.withValues(alpha: 0.12),
                bottomColor.withValues(alpha: 0.28),
                bottomColor.withValues(alpha: 0.55),
                bottomColor,
              ],
              stops: const [0.0, 0.30, 0.55, 0.80, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared slider helpers
// ─────────────────────────────────────────────────────────────────────────────

class _PillTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackH = sliderTheme.trackHeight ?? 8;
    final top = offset.dy + (parentBox.size.height - trackH) / 2;
    return Rect.fromLTWH(offset.dx, top, parentBox.size.width, trackH);
  }
}

class _ShadowedThumbShape extends RoundSliderThumbShape {
  const _ShadowedThumbShape({required double radius})
      : super(enabledThumbRadius: radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final fontSize = enabledThumbRadius * 2.2;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.star_rounded.codePoint),
        style: TextStyle(
          fontSize: fontSize,
          fontFamily: Icons.star_rounded.fontFamily,
          color: const Color(0xFFFFD700),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      center - Offset(tp.width / 2, tp.height / 2),
    );
  }
}
