import 'dart:math';

import 'package:flutter/material.dart';

/// Monthly line chart shared by the Stats ANALYTICS card and the Max welcome
/// sheet GRAPH card — one painter, identical rendering in both places:
/// bars + smooth line for elapsed months, faded regression trajectory for
/// future months. Feed it cumulative monthly totals and the line only ever
/// rises gradually.
class MonthlyLinePainter extends CustomPainter {
  final List<int> data;
  final Color lineColor;
  final int currentMonth;

  MonthlyLinePainter({
    required this.data,
    required this.lineColor,
    required this.currentMonth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final count = min(currentMonth + 1, data.length);
    if (count < 2) return;

    final maxVal = data.sublist(0, count).reduce(max).clamp(1, 9999999);
    final totalMonths = data.length;
    final points = <Offset>[];

    for (int i = 0; i < count; i++) {
      final x = i / (totalMonths - 1) * size.width;
      final y = size.height - (data[i] / maxVal * size.height * 0.85) - 4;
      points.add(Offset(x, y));
    }

    // Linear regression on existing data
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < count; i++) {
      sumX += i;
      sumY += data[i];
      sumXY += i * data[i];
      sumX2 += i * i;
    }
    final slope = (count * sumXY - sumX * sumY) / (count * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / count;

    final barPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final barW = size.width / totalMonths * 0.4;

    // Draw bars for existing data
    for (int i = 0; i < count; i++) {
      final x = i / (totalMonths - 1) * size.width;
      final barH = (data[i] / maxVal * size.height * 0.85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, size.height - barH / 2 - 4),
            width: barW,
            height: barH,
          ),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }

    // Draw fill
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Draw smooth line for existing data
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (points.length >= 2) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final cpx = (prev.dx + curr.dx) / 2;
        linePath.cubicTo(cpx, prev.dy, cpx, curr.dy, curr.dx, curr.dy);
      }
      canvas.drawPath(linePath, linePaint);
    }

    // ── Estimated trajectory ──────────────────────────────────────────
    if (count < totalMonths) {
      final projectedPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.45)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final projPoints = <Offset>[];
      for (int i = count; i < totalMonths; i++) {
        final projVal = (slope * i + intercept).clamp(0, maxVal * 1.5).toInt();
        final x = i / (totalMonths - 1) * size.width;
        final y = size.height - (projVal / maxVal * size.height * 0.85) - 4;
        projPoints.add(Offset(x, y));

        // Bars for projected months
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, size.height - (projVal / maxVal * size.height * 0.85) / 2 - 4),
              width: barW,
              height: projVal / maxVal * size.height * 0.85,
            ),
            const Radius.circular(2),
          ),
          barPaint,
        );
      }

      if (projPoints.isNotEmpty) {
        final allPoints = [...points, ...projPoints];
        final projPath = Path()
          ..moveTo(allPoints.first.dx, allPoints.first.dy);
        for (int i = 1; i < allPoints.length; i++) {
          final prev = allPoints[i - 1];
          final curr = allPoints[i];
          final cpx = (prev.dx + curr.dx) / 2;
          projPath.cubicTo(cpx, prev.dy, cpx, curr.dy, curr.dx, curr.dy);
        }
        canvas.drawPath(projPath, projectedPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
