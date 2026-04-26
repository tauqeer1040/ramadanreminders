import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:material_new_shapes/material_new_shapes.dart';
import '../services/prayer_time_service.dart';
import 'package:adhan/adhan.dart';
import './task_carousel.dart';
import './action_prompt_card.dart';
import './sawab_countdown_card.dart';
import '../services/notification_service.dart';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'profile_bottom_sheet.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final int _streakCount = 82; // Example streak count
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    
    // Listen to Auth state to refresh the dynamic avatar automatically!
    AuthService.authStateChanges.listen((user) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _checkPermissions() async {
    final enabled = await NotificationService.checkPermissions();
    if (mounted) {
      setState(() {
        _notificationsEnabled = enabled;
      });
    }
  }

  Future<void> _handleNotificationRequest() async {
    await NotificationService.requestPermissions();
    await _checkPermissions();
    if (_notificationsEnabled) {
      await NotificationService.scheduleDailyNotifications();
    }
  }

  @override
  void dispose() {
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
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                            ),
                            builder: (context) => const ProfileBottomSheet(),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Builder(
                          builder: (context) {
                            final user = AuthService.currentUser;
                            final isGuest = user == null || user.isAnonymous;
                            
                            return CircleAvatar(
                              radius: 20,
                              backgroundColor: cs.primaryContainer,
                              child: Container(
                                clipBehavior: Clip.antiAlias,
                                decoration: const BoxDecoration(shape: BoxShape.circle),
                                child: isGuest
                                  ? Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Image.asset('assets/photos/mascot/trophy.png', fit: BoxFit.contain),
                                    )
                                  : (user.photoURL != null && user.photoURL!.isNotEmpty)
                                    ? Image.network(user.photoURL!, fit: BoxFit.cover)
                                    : Icon(Icons.person_rounded, color: cs.onPrimaryContainer, size: 24),
                              ),
                            );
                          }
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

                // ── Bounded Task Carousel ─────────────────────────────────────────────
                SizedBox(
                  height: 380,
                  child: const TaskCarousel(),
                ),

                const SizedBox(height: 32),

                // ── Prayer / Sehri / Iftar Timings ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: FutureBuilder<PrayerTimes?>(
                    future: PrayerTimeService.getPrayerTimes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: ExpressiveLoadingIndicator(
                            polygons: [
                              MaterialShapes.softBurst,
                              MaterialShapes.heart,
                              MaterialShapes.pill,
                              MaterialShapes.pentagon,
                            ],
                          ),
                        );
                      }
                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data == null) {
                        return ActionPromptCard(
                          title: 'Enable Location',
                          subtitle:
                              'Please enable location access to view accurate prayer times for your region.',
                          buttonText: 'Enable',
                          onPressed: () async {
                            final granted =
                                await PrayerTimeService.requestLocationPermission();
                            if (granted && mounted) {
                              setState(() {}); // Rebuild to fetch timings
                            }
                          },
                          backgroundColor: const Color(
                            0xFFE8F5E9,
                          ), // Light green
                          foregroundColor: const Color(
                            0xFF1B5E20,
                          ), // Dark green
                          icon: const Icon(
                            Icons.location_on_rounded,
                            size: 64,
                            color: Color(0xFF4CAF50),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          if (mounted)
                            SawabCountdownCard(timings: snapshot.data!),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // ── Share Button ──────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFf09433),
                          Color(0xFFe6683c),
                          Color(0xFFdc2743),
                          Color(0xFFcc2366),
                          Color(0xFFbc1888),
                        ],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: FilledButton(
                      onPressed: () {
                        // Trigger instagram share action here
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
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
                ),

                const SizedBox(height: 32),

                // ── Action Prompts (Notifications & Widgets) ────────────────────────
                if (!_notificationsEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ActionPromptCard(
                      title: 'Set the reminder',
                      subtitle:
                          'Never miss your morning routine!\nSet a reminder to stay on track',
                      buttonText: 'Set Now',
                      onPressed: _handleNotificationRequest,
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
                ],

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
      ],
    );
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
