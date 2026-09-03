import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/revenuecat_service.dart';

/// Twitter-style circular character counter with a "Write more with Max" upsell.
///
/// Shows a circular progress ring that changes color as the user approaches
/// the limit, plus a small count label. When the limit is reached, a compact
/// banner nudges the user toward the Pro upgrade.
class TweetCounter extends StatefulWidget {
  final int currentLength;
  final int maxLength;
  final bool showProUpsell;

  const TweetCounter({
    super.key,
    required this.currentLength,
    this.maxLength = 280,
    this.showProUpsell = true,
  });

  @override
  State<TweetCounter> createState() => _TweetCounterState();
}

class _TweetCounterState extends State<TweetCounter> {
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('onboarding_displayName');
    if (mounted) setState(() => _userName = name);
  }

  double get _progress => (widget.currentLength / widget.maxLength).clamp(0.0, 1.0);
  bool get _isAtLimit => widget.currentLength >= widget.maxLength;
  bool get _isNearLimit => _progress >= 0.9;

  Color _progressColor(BuildContext context) {
    if (_isAtLimit) return const Color(0xFFE0245E); // Twitter red
    if (_isNearLimit) return const Color(0xFFFFAD1F); // Twitter yellow
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final color = _progressColor(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_isNearLimit || _isAtLimit)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '${widget.currentLength}/${widget.maxLength}',
                  style: tt.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            // Circular progress ring
            SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(
                painter: _CircularProgressPainter(
                  progress: _progress.clamp(0.0, 1.0),
                  color: color,
                  backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ],
        ),
        if (_isAtLimit && widget.showProUpsell) ...[
          const SizedBox(height: 8),
          _ProUpsellBanner(cs: cs, userName: _userName),
        ],
      ],
    );
  }
}

class _ProUpsellBanner extends StatelessWidget {
  final ColorScheme cs;
  final String? userName;
  const _ProUpsellBanner({required this.cs, this.userName});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        try {
          await RevenueCatService.instance.presentPaywall(
            displayCloseButton: true,
          );
        } catch (_) {}
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFD4AF37).withValues(alpha: 0.12),
              const Color(0xFFD4AF37).withValues(alpha: 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Image.asset(
                'assets/photos/mascot/face.webp',
                width: 18,
                height: 18,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              userName != null ? '$userName, write more with Max' : 'Write more with Max',
              style: tt.labelMedium?.copyWith(
                color: const Color(0xFFD4AF37),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start from top
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
