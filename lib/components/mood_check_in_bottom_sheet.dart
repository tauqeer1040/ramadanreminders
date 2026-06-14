import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_background.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────

class MoodEntry {
  final double value; // 0.0 – 1.0
  final DateTime timestamp;

  const MoodEntry({required this.value, required this.timestamp});
}

// ─────────────────────────────────────────────────────────────────────────────
// Mood helpers
// ─────────────────────────────────────────────────────────────────────────────

String moodLabel(double value) {
  if (value < 0.15) return 'Very Unpleasant';
  if (value < 0.30) return 'Unpleasant';
  if (value < 0.45) return 'Slightly Unpleasant';
  if (value < 0.55) return 'Neutral';
  if (value < 0.70) return 'Slightly Pleasant';
  if (value < 0.85) return 'Pleasant';
  return 'Very Pleasant';
}

/// Returns a list of [Color]s for a given mood value.
/// Low moods → cool blue/purple; high moods → warm green/gold.
List<Color> moodColors(double value) {
  if (value < 0.20) {
    // Very Unpleasant – icy blue-grey
    return [
      const Color(0xFFB0BEC5),
      const Color(0xFF78909C),
      const Color(0xFF546E7A),
    ];
  } else if (value < 0.40) {
    // Unpleasant – muted indigo
    return [
      const Color(0xFF9FA8DA),
      const Color(0xFF5C6BC0),
      const Color(0xFF3949AB),
    ];
  } else if (value < 0.55) {
    // Neutral – lavender
    return [
      const Color(0xFFCE93D8),
      const Color(0xFFAB47BC),
      const Color(0xFF7B1FA2),
    ];
  } else if (value < 0.70) {
    // Slightly Pleasant – mint-teal
    return [
      const Color(0xFF80CBC4),
      const Color(0xFF26A69A),
      const Color(0xFF00796B),
    ];
  } else if (value < 0.85) {
    // Pleasant – lime-green
    return [
      const Color(0xFFAED581),
      const Color(0xFF7CB342),
      const Color(0xFF558B2F),
    ];
  } else {
    // Very Pleasant – amber-gold
    return [
      const Color(0xFFFFD54F),
      const Color(0xFFFFB300),
      const Color(0xFFFF8F00),
    ];
  }
}

/// Background gradient colour for the whole bottom-sheet area.
Color moodBgColor(double value) {
  final colors = moodColors(value);
  return colors[0].withValues(alpha: 0.12);
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painter – animated M3 mood shape
// ─────────────────────────────────────────────────────────────────────────────

/// Draws concentric, softened/sharpened star/blob shapes.
/// [sharpness] 0.0 = very fluffy blob  |  1.0 = pointy star
/// [rotationAngle] rotates slowly over time.
class _MoodShapePainter extends CustomPainter {
  final double sharpness;  // 0.0 (fluffy) → 1.0 (sharp)
  final double rotationAngle;
  final List<Color> colors;
  final int rings;

  const _MoodShapePainter({
    required this.sharpness,
    required this.rotationAngle,
    required this.colors,
    this.rings = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxRadius = size.width / 2 * 0.9;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotationAngle);

    for (int ring = rings; ring >= 1; ring--) {
      final fraction = ring / rings;
      final radius = maxRadius * fraction;

      // The number of petals/points interpolates between 5 (fluffy) and 8 (sharp)
      final petals = 5 + (sharpness * 3).round();

      // Inner radius controls how "star-like" the shape is.
      // Fluffy → inner ≈ 0.82 (barely pinched) ; sharp → inner ≈ 0.45 (very pinched)
      final innerFraction = 0.82 - sharpness * 0.37;
      final innerRadius = radius * innerFraction;

      // Choose colour based on ring depth
      final colorIndex = ((ring - 1) / (rings - 1) * (colors.length - 1))
          .round()
          .clamp(0, colors.length - 1);
      final opacity = 0.25 + fraction * 0.6;

      final paint = Paint()
        ..color = colors[colorIndex].withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final path = _buildStarPath(petals, radius, innerRadius);

      // Slight rotation per ring for an organic feel
      canvas.save();
      canvas.rotate(ring * (pi / petals) * 0.4);
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    canvas.restore();
  }

  Path _buildStarPath(int petals, double outerR, double innerR) {
    final totalPoints = petals * 2;
    final path = Path();

    for (int i = 0; i <= totalPoints; i++) {
      final angle = (i / totalPoints) * 2 * pi - pi / 2;
      final r = i.isEven ? outerR : innerR;

      // Soften the tips of fluffy shapes with a tiny cubic bezier trick.
      // For simplicity we use lineTo; smoothing is achieved via the
      // innerFraction already making the shape blob-like.
      final x = cos(angle) * r;
      final y = sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_MoodShapePainter old) =>
      old.sharpness != sharpness ||
      old.rotationAngle != rotationAngle ||
      old.colors != colors;
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated shape widget
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedMoodShape extends StatefulWidget {
  final double moodValue; // 0.0 – 1.0
  final bool paused;

  const _AnimatedMoodShape({required this.moodValue, this.paused = false});

  @override
  State<_AnimatedMoodShape> createState() => _AnimatedMoodShapeState();
}

class _AnimatedMoodShapeState extends State<_AnimatedMoodShape>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotController;
  late Animation<double> _rot;

  @override
  void initState() {
    super.initState();
    _rotController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    if (!widget.paused) _rotController.repeat();
    _rot = Tween<double>(begin: 0, end: 2 * pi).animate(_rotController);
  }

  @override
  void didUpdateWidget(_AnimatedMoodShape old) {
    super.didUpdateWidget(old);
    if (widget.paused != old.paused) {
      if (widget.paused) {
        _rotController.stop();
      } else {
        _rotController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _rotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sharpness = 1.0 - widget.moodValue;
    final colors = moodColors(widget.moodValue);

    if (widget.paused) {
      return CustomPaint(
        size: const Size(240, 240),
        painter: _MoodShapePainter(
          sharpness: sharpness,
          rotationAngle: _rot.value,
          colors: colors,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _rot,
      builder: (_, child) => CustomPaint(
        size: const Size(240, 240),
        painter: _MoodShapePainter(
          sharpness: sharpness,
          rotationAngle: _rot.value,
          colors: colors,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class MoodCheckInBottomSheet extends StatefulWidget {
  const MoodCheckInBottomSheet({super.key});

  @override
  State<MoodCheckInBottomSheet> createState() => _MoodCheckInBottomSheetState();
}

class _MoodCheckInBottomSheetState extends State<MoodCheckInBottomSheet> {
  double _moodValue = 0.5;
  bool _isDragging = false;
  String _displayedLabel = 'Neutral';

  @override
  void initState() {
    super.initState();
    _displayedLabel = moodLabel(_moodValue);
  }

  void _onSliderChanged(double v) {
    final newLabel = moodLabel(v);
    setState(() {
      _moodValue = v;
      _displayedLabel = newLabel;
    });
  }

  void _onSliderChangeStart(double v) {
    setState(() => _isDragging = true);
  }

  void _onSliderChangeEnd(double v) {
    HapticFeedback.selectionClick();
    setState(() => _isDragging = false);
  }

  void _onSave() {
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop(
      MoodEntry(value: _moodValue, timestamp: DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final colors = moodColors(_moodValue);
    final primaryColor = colors[1];

    return AppBackground(
      overlayOpacity: 0.55,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: [
            // ── Drag handle ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title bar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Text(
                    'How are you feeling?',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(backgroundColor: Colors.transparent),
                  ),
                ],
              ),
            ),

            // ── Animated shape ─────────────────────────────────────────
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _AnimatedMoodShape(
                    moodValue: _moodValue,
                    paused: _isDragging,
                  ),

                  const SizedBox(height: 28),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      _displayedLabel,
                      key: ValueKey(_displayedLabel),
                      style: tt.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Slider ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: primaryColor,
                            inactiveTrackColor:
                                cs.surfaceContainerHigh.withValues(alpha: 0.6),
                            thumbColor: cs.surface,
                            overlayColor: primaryColor.withValues(alpha: 0.18),
                            thumbShape: _GlassThumbShape(
                              thumbColor: primaryColor,
                              surfaceColor: cs.surface,
                            ),
                            trackHeight: 6,
                            trackShape: const RoundedRectSliderTrackShape(),
                          ),
                          child: Slider(
                            value: _moodValue,
                            min: 0.0,
                            max: 1.0,
                            onChanged: _onSliderChanged,
                            onChangeStart: _onSliderChangeStart,
                            onChangeEnd: _onSliderChangeEnd,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Very Unpleasant',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Very Pleasant',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.45),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Save button (M3 FilledButton) ──────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOutCubic,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [colors[0], colors[1]],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _onSave,
                            borderRadius: BorderRadius.circular(28),
                            child: Center(
                              child: Text(
                                'Log Mood',
                                style: tt.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom glass thumb for the slider
// ─────────────────────────────────────────────────────────────────────────────

class _GlassThumbShape extends SliderComponentShape {
  final Color thumbColor;
  final Color surfaceColor;

  const _GlassThumbShape({required this.thumbColor, required this.surfaceColor});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size(28, 28);

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
    // Outer glow
    canvas.drawCircle(
      center,
      16,
      Paint()
        ..color = thumbColor.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // White surface circle
    canvas.drawCircle(
      center,
      13,
      Paint()..color = surfaceColor,
    );
    // Coloured ring
    canvas.drawCircle(
      center,
      13,
      Paint()
        ..color = thumbColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    // Inner dot
    canvas.drawCircle(
      center,
      4,
      Paint()..color = thumbColor,
    );
  }
}
