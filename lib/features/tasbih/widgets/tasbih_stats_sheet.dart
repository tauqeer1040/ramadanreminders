import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:fl_chart/fl_chart.dart';
import '../controller/tasbih_controller.dart';

void showTasbihStatsSheet(BuildContext context, TasbihController controller) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SizedBox(
      // height: MediaQuery.of(context).size.height * 0.65,
      child: _TasbihStatsSheet(controller: controller),
    ),
  );
}

class _TasbihStatsSheet extends StatefulWidget {
  final TasbihController controller;

  const _TasbihStatsSheet({required this.controller});

  @override
  State<_TasbihStatsSheet> createState() => _TasbihStatsSheetState();
}

class _TasbihStatsSheetState extends State<_TasbihStatsSheet> {
  int _dragCount = 0;
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dhikrs = widget.controller.dhikrList;

    // Sort dhikrs by total count (descending) or keep original order. Let's keep original for radar.
    final totalOverall = widget.controller.totalCount;

    // Define a vibrant palette for the chart details
    final colors = [
      const Color(0xFFFDD835), // Yellow
      const Color(0xFF66BB6A), // Green
      const Color(0xFFFF8A65), // Orange
      const Color(0xFF64B5F6), // Blue
      const Color(0xFFE57373), // Red
      const Color(0xFFBA68C8), // Purple
      const Color(0xFF4DB6AC), // Teal
    ];

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 24),
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                // Top Chart Area
                SizedBox(
                  height: 280,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Gradient Background
                      Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              cs.primaryContainer.withValues(alpha: 0.2),
                              cs.secondaryContainer.withValues(alpha: 0.4),
                              cs.surface,
                            ],
                            stops: const [0.3, 0.7, 1.0],
                          ),
                        ),
                      ),

                      // The Chart
                      if (dhikrs.length >= 3)
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: RadarChart(
                            RadarChartData(
                              radarShape: RadarShape.polygon,
                              dataSets: [
                                RadarDataSet(
                                  fillColor: cs.primary.withValues(alpha: 0.1),
                                  borderColor: cs.primary,
                                  borderWidth: 2,
                                  entryRadius: 6,
                                  dataEntries: dhikrs.map((d) {
                                    return RadarEntry(
                                      value: d.total.toDouble(),
                                    );
                                  }).toList(),
                                ),
                              ],
                              radarBackgroundColor: Colors.transparent,
                              borderData: FlBorderData(show: false),
                              radarBorderData: const BorderSide(
                                color: Colors.transparent,
                              ),
                              titlePositionPercentageOffset: 0.2,
                              titleTextStyle: TextStyle(
                                fontSize: 10,
                                color: cs.onSurface,
                              ),
                              tickCount: 1,
                              ticksTextStyle: const TextStyle(
                                color: Colors.transparent,
                              ),
                              tickBorderData: const BorderSide(
                                color: Colors.transparent,
                              ),
                              gridBorderData: BorderSide(
                                color: cs.outlineVariant.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            // swapAnimationDuration: const Duration(milliseconds: 150), // Optional
                            // swapAnimationCurve: Curves.linear, // Optional
                          ),
                        ),

                      if (dhikrs.length < 3)
                        Text(
                          'Add at least 3 Tasbihs\nfor the radar chart!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),

                      // Center Total Pill
                      // Container(
                      //   padding: const EdgeInsets.all(20),
                      //   decoration: BoxDecoration(
                      //     color: cs.surfaceContainerHighest,
                      //     shape: BoxShape.circle,
                      //     boxShadow: [
                      //       BoxShadow(
                      //         color: Colors.black12,
                      //         blurRadius: 10,
                      //         offset: Offset(0, 4),
                      //       ),
                      //     ],
                      //   ),
                      //   child: Text(
                      //     totalOverall.toString(),
                      //     style: TextStyle(
                      //       fontSize: 28,
                      //       fontWeight: FontWeight.w900,
                      //       color: cs.primary,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Breakdown Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Breakdown',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // List of breakdowns
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 8.0,
                    ),
                    itemCount: dhikrs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final dhikr = dhikrs[index];
                      final color = colors[index % colors.length];

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          // border: Border.all(
                          //   color: cs.outlineVariant.withValues(alpha: 0.5),
                          //   width: 1.5,
                          // ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            // Colored Ring
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: color, width: 3.5),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // Title
                            Expanded(
                              child: Text(
                                dhikr.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            // Count
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'x ${dhikr.total}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                  // TextSpan(
                                  //   text: ' / Total',
                                  //   style: TextStyle(
                                  //     fontSize: 14,
                                  //     fontWeight: FontWeight.w600,
                                  //     color: cs.onSurfaceVariant.withValues(
                                  //       alpha: 0.6,
                                  //     ),
                                  //   ),
                                  // ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Continue Button bottom
                // (Commented out initially by user)

                // Easter Egg Area
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    if (details.primaryDelta != null &&
                        details.primaryDelta! < -2) {
                      // Only count distinct up-swipes by checking an accumulating delta or just simple velocity
                    }
                  },
                  onVerticalDragEnd: (details) {
                    // If the user swiped UP
                    if (details.primaryVelocity != null &&
                        details.primaryVelocity! < -100) {
                      setState(() {
                        if (_dragCount < 3) {
                          _dragCount++;
                          if (_dragCount == 3) {
                            HapticFeedback.mediumImpact();
                            _confettiController.play();
                          } else {
                            HapticFeedback.lightImpact();
                          }
                        }
                      });
                    } else if (details.primaryVelocity != null &&
                        details.primaryVelocity! > 100) {
                      // Swipe DOWN hides it
                      setState(() {
                        if (_dragCount > 0) {
                          _dragCount--;
                        }
                      });
                    }
                  },
                  child: AnimatedContainer(
                    decoration: BoxDecoration(color: Colors.transparent),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    height: _dragCount == 0
                        ? 70
                        : (_dragCount == 1
                              ? 90
                              : (_dragCount == 2 ? 130 : 160)),
                    width: double.infinity,
                    alignment: Alignment.bottomCenter,
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.topCenter,
                        heightFactor: _dragCount == 0
                            ? 0.0
                            : (_dragCount == 1
                                  ? 0.4
                                  : (_dragCount == 2 ? 0.7 : 1.0)),
                        child: Image.asset(
                          'assets/photos/mascot/dua2.png',
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.01, // Single burst feel
                numberOfParticles: 35, // Satisfying but not overwhelming
                maxBlastForce: 45, // Pops up nicely
                minBlastForce: 20,
                gravity: 0.4, // Falls back gracefully
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
