import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:confetti/confetti.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import '../services/prayer_time_service.dart';
import 'package:adhan/adhan.dart';
import './task_carousel.dart';
import './action_prompt_card.dart';
import './sawab_countdown_card.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final int _streakCount = 82; // Example streak count
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 1500),
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
    final tt = Theme.of(context).textTheme;

    // Generate last 7 days ending today
    final today = DateTime.now();
    final List<DateTime> last7Days = List.generate(
      7,
      (index) => today.subtract(Duration(days: 6 - index)),
    );

    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top Bar: Streak and Profile Avatar ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Streak badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(
                              '$_streakCount',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Profile avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: cs.secondaryContainer,
                        child: Icon(
                          Icons.person_rounded,
                          color: cs.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Title ─────────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Builder(
                    builder: (context) {
                      final hijriDate = PrayerTimeService.getDynamicHijriDate();
                      return Text(
                        'Day ${hijriDate.hDay} of ${hijriDate.longMonthName}',
                        textAlign: TextAlign.center,
                        style: tt.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                          height: 1.2,
                          fontSize: 28,
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ── Streak Dots (Last 7 Days) ─────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(7, (index) {
                    final d = last7Days[index];
                    final isToday = index == 6; // Always the rightmost one
                    final isPast = index < 6;
                    final initial = DateFormat(
                      'E',
                    ).format(d).substring(0, 1).toLowerCase();

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isPast
                                  ? cs
                                        .primary // Filled for previous days
                                  : Colors
                                        .transparent, // Empty or partially filled for today
                              border: Border.all(
                                color: isPast ? cs.primary : cs.outlineVariant,
                                width:
                                    2, // Thicker border for unfilled to match image style
                              ),
                            ),
                            child: isToday
                                ? Center(
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            initial,
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 32),

                // ── Prayer / Sehri / Iftar Timings ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: FutureBuilder<PrayerTimes?>(
                    future: PrayerTimeService.getPrayerTimes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: ExpressiveLoadingIndicator(
                        polygons: [
                          MaterialShapes.softBurst,
                          MaterialShapes.heart,
                          MaterialShapes.pill,
                          MaterialShapes.pentagon,
                        ],
                      ),);
                      }
                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data == null) {
                        return const Text(
                          'Enable location to view Sehri & Iftar timings.',
                          textAlign: TextAlign.center,
                        );
                      }

                      // final timings = snapshot.data!;
                      // final timeFormat = DateFormat.jm();
                      // final sehri = timeFormat.format(timings.fajr);
                      // final namaz = timeFormat.format(timings.dhuhr);
                      // final iftar = timeFormat.format(timings.maghrib);

                      return Column(
                        children: [
                          if (mounted)
                            SawabCountdownCard(timings: snapshot.data!),
                          // const SizedBox(height: 16),
                          // Container(
                          //   padding: const EdgeInsets.all(20),
                          //   decoration: BoxDecoration(
                          //     color: cs.secondaryContainer,
                          //     borderRadius: BorderRadius.circular(24),
                          //   ),
                            // child: Row(
                            //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            //   children: [
                            //     _TimingWidget(
                            //       title: 'Sehri',
                            //       time: sehri,
                            //       icon: Icons.wb_twilight,
                            //       color: Colors.blueAccent,
                            //     ),
                            //     _TimingWidget(
                            //       title: 'Namaz (Dhuhr)',
                            //       time: namaz,
                            //       icon: Icons.access_time_filled,
                            //       color: Colors.green,
                            //     ),
                            //     _TimingWidget(
                            //       title: 'Iftar',
                            //       time: iftar,
                            //       icon: Icons.nights_stay,
                            //       color: Colors.orange,
                            //     ),
                            //   ],
                            // ),
                          // ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // ── Share Button ──────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: FilledButton(
                    onPressed: () {
                      // Trigger instagram share action here
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(
                        0xFFFF453A,
                      ), // Vibrant coral/red
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'SHARE',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.ios_share_rounded, size: 22),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Bounded Task Carousel ─────────────────────────────────────────────
                SizedBox(
                  height: 380,
                  child: TaskCarousel(onTaskCompleted: _playConfetti),
                ),

                // SizedBox(
                //   height: 380,
                //   child: TaskScreen()
                // ),
                const SizedBox(height: 32),

                // ── Action Prompts (Notifications & Widgets) ────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ActionPromptCard(
                    title: 'Set the reminder',
                    subtitle:
                        'Never miss your morning routine!\nSet a reminder to stay on track',
                    buttonText: 'Set Now',
                    onPressed: () {},
                    backgroundColor: const Color(
                      0xFFFFE0B2,
                    ), // Light peach/orange
                    foregroundColor: const Color(0xFF4E342E), // Dark brown
                    icon: const Icon(
                      Icons.notifications_active_rounded,
                      size: 64,
                      color: Color(0xFFFF7043),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ActionPromptCard(
                    title: 'Quick Access',
                    subtitle:
                        'Add a widget to your home screen\nfor instant access to your tasks.',
                    buttonText: 'Add Widget',
                    onPressed: () {},
                    backgroundColor: const Color(0xFFE1BEE7), // Light purple
                    foregroundColor: const Color(0xFF311B92), // Dark purple
                    icon: const Icon(
                      Icons.widgets_rounded,
                      size: 64,
                      color: Color(0xFFAB47BC),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Footer Mascot ──────────────────────
                Image.asset(
                  'assets/photos/mascot/trio.png',
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  
                ),
                // const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        IgnorePointer(
          child: Align(
            alignment: Alignment.center,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              colors: [cs.primary, cs.secondary, cs.tertiary],
            ),
          ),
        ),
      ],
    );
  }

  void _playConfetti() {
    _confettiController.play();
  }
}

class _TimingWidget extends StatelessWidget {
  final String title;
  final String time;
  final IconData icon;
  final Color color;

  const _TimingWidget({
    required this.title,
    required this.time,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          title,
          style: tt.labelMedium?.copyWith(
            color: cs.onSecondaryContainer.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: tt.titleMedium?.copyWith(
            color: cs.onSecondaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
