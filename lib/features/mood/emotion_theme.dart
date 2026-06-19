import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Return value from EmotionScreen
// ─────────────────────────────────────────────────────────────────────────────

class EmotionEntry {
  final double value; // 0.0 – 1.0
  final DateTime timestamp;

  const EmotionEntry({required this.value, required this.timestamp});
}

// ─────────────────────────────────────────────────────────────────────────────
// Resolved color set for a given slider position
// ─────────────────────────────────────────────────────────────────────────────

class EmotionColors {
  final String label;
  final Color petalColor;
  final Color glowColor;
  final Color bgTop;
  final Color bgMid;
  final Color bgBottom;

  const EmotionColors({
    required this.label,
    required this.petalColor,
    required this.glowColor,
    required this.bgTop,
    required this.bgMid,
    required this.bgBottom,
  });

  /// Button color: petal color darkened ~10 % in lightness.
  Color get buttonColor {
    final hsl = HSLColor.fromColor(petalColor);
    return hsl
        .withLightness((hsl.lightness - 0.10).clamp(0.0, 1.0))
        .toColor();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Key-frame presets (0.0 / 0.25 / 0.50 / 0.75 / 1.0)
// ─────────────────────────────────────────────────────────────────────────────

class _Preset {
  final String label;
  final Color petalColor;
  final Color glowColor;
  final Color bgTop;
  final Color bgMid;
  final Color bgBottom;

  const _Preset({
    required this.label,
    required this.petalColor,
    required this.glowColor,
    required this.bgTop,
    required this.bgMid,
    required this.bgBottom,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme interpolation
// ─────────────────────────────────────────────────────────────────────────────

class EmotionTheme {
  static const List<_Preset> _presets = [
    // 0.00 – Very Unpleasant (deep purple)
    _Preset(
      label: 'Very Unpleasant',
      petalColor: Color(0xFF8B63B3),
      glowColor: Color(0xFF9B73C3),
      bgTop: Color(0xFFE2DBEC),
      bgMid: Color(0xFFD2C7E2),
      bgBottom: Color(0xFFA189C6),
    ),
    // 0.25 – Unpleasant (blue)
    _Preset(
      label: 'Unpleasant',
      petalColor: Color(0xFF5782E2),
      glowColor: Color(0xFF6792F2),
      bgTop: Color(0xFFE2EAF7),
      bgMid: Color(0xFFCDDAF2),
      bgBottom: Color(0xFF92AFE6),
    ),
    // 0.50 – Neutral (white/off-white)
    _Preset(
      label: 'Neutral',
      petalColor: Color(0xFFFFFFFF),
      glowColor: Color(0xFFF8F9FA),
      bgTop: Color(0xFFF5F5F5),
      bgMid: Color(0xFFEBEBEB),
      bgBottom: Color(0xFFDDDDDD),
    ),
    // 0.75 – Pleasant (teal/green)
    _Preset(
      label: 'Pleasant',
      petalColor: Color(0xFF4CAE91),
      glowColor: Color(0xFF5CBEA1),
      bgTop: Color(0xFFE3F3EF),
      bgMid: Color(0xFFCDECE4),
      bgBottom: Color(0xFF8CCFB8),
    ),
    // 1.00 – Very Pleasant (golden yellow)
    _Preset(
      label: 'Very Pleasant',
      petalColor: Color(0xFFFFD700),
      glowColor: Color(0xFFFFDF40),
      bgTop: Color(0xFFFFF8E1),
      bgMid: Color(0xFFFFEAA0),
      bgBottom: Color(0xFFFFD54F),
    ),
  ];

  /// Returns smoothly interpolated [EmotionColors] for [value] ∈ [0, 1].
  static EmotionColors lerp(double value) {
    final t = value.clamp(0.0, 1.0) * (_presets.length - 1);
    final lo = _presets[t.floor()];
    final hi = _presets[t.ceil()];
    final f = t - t.floor();

    return EmotionColors(
      label: f < 0.5 ? lo.label : hi.label,
      petalColor: Color.lerp(lo.petalColor, hi.petalColor, f)!,
      glowColor: Color.lerp(lo.glowColor, hi.glowColor, f)!,
      bgTop: Color.lerp(lo.bgTop, hi.bgTop, f)!,
      bgMid: Color.lerp(lo.bgMid, hi.bgMid, f)!,
      bgBottom: Color.lerp(lo.bgBottom, hi.bgBottom, f)!,
    );
  }
}
