import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
// import 'package:marquee/marquee.dart';
import 'package:text_scroll/text_scroll.dart';

class SawabCountdownCard extends StatefulWidget {
  final PrayerTimes timings;

  const SawabCountdownCard({super.key, required this.timings});

  @override
  State<SawabCountdownCard> createState() => _SawabCountdownCardState();
}

class _SawabCountdownCardState extends State<SawabCountdownCard> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final fajr = widget.timings.fajr;
    final maghrib = widget.timings.maghrib;

    bool isFasting = _now.isAfter(fajr) && _now.isBefore(maghrib);
    bool isBeforeFajr = _now.isBefore(fajr);

    DateTime targetTime;
    String titleText;
    double progress = 0.0;
    String progressString = "";

    if (isFasting) {
      targetTime = maghrib;
      titleText =
          'Golden hours of Fasting remaining, Please make the most of it 😄 Say Bismillah 🩷 Read an Aayah of Quran in the Quran page 🌟 Make Dua 🤲 Recite Tasbeeh 📿 Mark just 3 tasks completed everyday 🎯';
      final totalFastingDuration = maghrib.difference(fajr).inSeconds;
      final elapsed = _now.difference(fajr).inSeconds;
      progress = (elapsed / totalFastingDuration).clamp(0.0, 1.0);
      progressString = '${(progress * 100).toInt()}% of fasting completed';
    } else if (isBeforeFajr) {
      targetTime = fajr;
      titleText = 'Time left to earn Sawab before Sehri';
      progress = 0.0;
      progressString = 'Fast has not started yet';
    } else {
      targetTime = _now;
      titleText =
          '🌙 Congratulations on a successful fast! May Allah accept it';
      progress = 1.0;
      progressString = '100% fasting completed';
    }

    Duration remaining = targetTime.difference(_now);
    if (remaining.isNegative) remaining = Duration.zero;

    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    final timeFormat = DateFormat.jm();
    final startTimeStr = timeFormat.format(fajr);
    final endTimeStr = timeFormat.format(maghrib);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          TextScroll(
            titleText,
            velocity: Velocity(pixelsPerSecond: Offset(40, 0)),
            mode: TextScrollMode.endless,
            delayBefore: Duration(milliseconds: 400),
            // numberOfReps: 10,
            fadedBorder: true,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              overflow: TextOverflow.fade,
            ),
          ),
          // Marquee(
          //   text: "jjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjjj",
          //   scrollAxis: Axis.horizontal,
          //   crossAxisAlignment: CrossAxisAlignment.start,
          //   blankSpace: 20.0,
          //   velocity: 100.0,
          //   pauseAfterRound: Duration(seconds: 1),
          //   startPadding: 10.0,
          //   accelerationDuration: Duration(seconds: 1),
          //   accelerationCurve: Curves.linear,
          //   decelerationDuration: Duration(milliseconds: 500),
          //   decelerationCurve: Curves.easeOut,
          // ),
          // Text(
          //    titleText,
          //   // maxLines: 1,
          //   style: tt.titleMedium?.copyWith(
          //     fontWeight: FontWeight.w600,
          //     color: cs.onSurface,
          //     overflow: TextOverflow.fade,
          //   ),
          // ),
          const SizedBox(height: 24),
          if (isFasting || isBeforeFajr) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeUnit(hours, 'HOURS', tt, cs),
                _buildColon(tt, cs),
                _buildTimeUnit(minutes, 'MINUTES', tt, cs),
                _buildColon(tt, cs),
                _buildTimeUnit(seconds, 'SECONDS', tt, cs),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.wb_twilight,
                      size: 14,
                      color: cs.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      startTimeStr,
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      endTimeStr,
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.nights_stay,
                      size: 14,
                      color: cs.primary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              borderRadius: BorderRadius.circular(10),
              backgroundColor: cs.outlineVariant.withValues(alpha: 0.3),
              color: cs.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 8),
            Text(
              progressString,
              style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildColon(TextTheme tt, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Text(
        ':',
        style: tt.headlineLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: cs.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildTimeUnit(
    String value,
    String label,
    TextTheme tt,
    ColorScheme cs,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: tt.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            fontSize: 42,
            color: cs.primary,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: tt.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
