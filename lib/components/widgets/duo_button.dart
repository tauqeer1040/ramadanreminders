import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/sfx_service.dart';

enum DuoSfxType { positive, negative, none }

/// Shared flowing-rainbow stops for high-visibility CTAs (Get Max).
const kRainbowBorderColors = <Color>[
  Color(0xFFFF1744), // red
  Color(0xFFFF9100), // orange
  Color(0xFFFFEA00), // yellow
  Color(0xFF00E676), // green
  Color(0xFF2979FF), // blue
  Color(0xFFD500F9), // violet
  Color(0xFFFF1744), // wrap for seamless sweep
];

class DuoButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color depthColor;
  final double height;
  final double radius;
  final Widget child;
  final bool dimOnDisabled;
  final DuoSfxType sfxType;

  /// Optional animated rainbow border around the top face. When null,
  /// the button renders exactly as before (solid face, no border).
  final List<Color>? borderGradientColors;
  final bool animateBorder;
  final double borderWidth;

  const DuoButton({
    super.key,
    required this.onPressed,
    required this.backgroundColor,
    required this.depthColor,
    required this.child,
    this.height = 52,
    this.radius = 12,
    this.dimOnDisabled = false,
    this.sfxType = DuoSfxType.none,
    this.borderGradientColors,
    this.animateBorder = false,
    this.borderWidth = 3,
  });

  @override
  State<DuoButton> createState() => _DuoButtonState();
}

class _DuoButtonState extends State<DuoButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  AnimationController? _borderCtrl;

  bool get _isDisabled => widget.onPressed == null;
  bool get _hasBorder =>
      widget.borderGradientColors != null &&
      widget.borderGradientColors!.length >= 2;

  void _playSfx() {
    if (widget.sfxType == DuoSfxType.none) return;
    final sfx = SfxService();
    if (widget.sfxType == DuoSfxType.positive) {
      sfx.playPositive();
    } else {
      sfx.playNegative();
    }
  }

  @override
  void didUpdateWidget(covariant DuoButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null && _pressed) {
      setState(() => _pressed = false);
    }
    _syncBorderCtrl();
  }

  @override
  void initState() {
    super.initState();
    _syncBorderCtrl();
  }

  void _syncBorderCtrl() {
    final want = _hasBorder && widget.animateBorder && !_isDisabled;
    if (want && _borderCtrl == null) {
      _borderCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      )..repeat();
    } else if (!want && _borderCtrl != null) {
      _borderCtrl!.dispose();
      _borderCtrl = null;
    }
  }

  @override
  void dispose() {
    _borderCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // --- ADJUST THESE TWO VALUES ---
    const double shadowHeight = 8.0; // The static thickness of the base
    final double travelDistance = _pressed ? shadowHeight : 0; // The movement depth
    // -------------------------------

    final bool isActuallyDisabled = _isDisabled && widget.dimOnDisabled;

    return Opacity(
      opacity: isActuallyDisabled ? 0.5 : 1.0,
      child: Listener(
        onPointerDown: _isDisabled
            ? null
            : (_) {
                HapticFeedback.lightImpact();
                _playSfx();
                setState(() => _pressed = true);
              },
        onPointerUp: (_) {
          if (mounted) {
            setState(() => _pressed = false);
            // Trigger the action on release for better UX and animation timing
            if (!_isDisabled && widget.onPressed != null) {
              widget.onPressed!();
            }
          }
        },
        onPointerCancel: (_) {
          if (mounted) setState(() => _pressed = false);
        },
        child: SizedBox(
          height: widget.height + shadowHeight,
          child: Stack(
            children: [
              // 1. THE BASE (The Shadow Part)
              // Pinned to the bottom of the stack
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: widget.depthColor,
                    borderRadius: BorderRadius.circular(widget.radius),
                  ),
                ),
              ),
              // 2. THE TOP (The Interactive Part)
              // This is what "slides" down to meet the base
              AnimatedPositioned(
                duration: const Duration(milliseconds: 60),
                top: travelDistance,
                left: 0,
                right: 0,
                child: _buildFace(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The pressable face: solid color, or solid color ringed by an
  /// (optionally animated) gradient border. Border is drawn *inside*
  /// the button's height so the face stays flush with the depth base.
  Widget _buildFace() {
    if (!_hasBorder) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
        child: widget.child,
      );
    }
    final innerH = (widget.height - widget.borderWidth * 2)
        .clamp(0.0, double.infinity);
    final face = Container(
      height: innerH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
      child: widget.child,
    );
    BoxDecoration frame(SweepGradient? sweep) => BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius + 2),
          gradient: sweep ??
              LinearGradient(
                colors: widget.borderGradientColors!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        );
    Widget framed(BoxDecoration decoration) => Container(
          height: widget.height,
          padding: EdgeInsets.all(widget.borderWidth),
          decoration: decoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: face,
          ),
        );
    if (widget.animateBorder && _borderCtrl != null) {
      return AnimatedBuilder(
        animation: _borderCtrl!,
        builder: (_, __) => framed(frame(SweepGradient(
          colors: widget.borderGradientColors!,
          transform: GradientRotation(_borderCtrl!.value * 6.28318),
        ))),
      );
    }
    return framed(frame(null));
  }
}
