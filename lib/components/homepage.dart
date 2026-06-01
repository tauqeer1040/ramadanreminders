import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/streak_service.dart';
import '../services/notification_service.dart';
import './task_carousel.dart';
import './action_prompt_card.dart';
import 'package:lottie/lottie.dart';
import 'about_bottom_sheet.dart';
import 'package:home_widget/home_widget.dart';


class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  int _streakCount = 1;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadStreak();
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

  Future<void> _loadStreak() async {
    final streak = await StreakService.getStreak();
    if (mounted) setState(() => _streakCount = streak);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
                            builder: (context) => const AboutBottomSheet(),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: cs.primaryContainer,
                          child: ClipOval(
                            child: Image.asset(
                              'assets/photos/mascot/hi.webp',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, color: cs.onSurface, size: 20),
                            ),
                          ),
                        ),
                      ),
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
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: Lottie.asset(
                                'assets/photos/elements/Streak Fire.json',
                                fit: BoxFit.contain,
                              ),
                            ),
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
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Title ─────────────────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    '3 tasks for you',
                    textAlign: TextAlign.center,
                    style: tt.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                      height: 1.2,
                      fontSize: 28,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Bounded Task Carousel ─────────────────────────────────────────────
                SizedBox(
                  height: 380,
                  child: const TaskCarousel(),
                ),

                const SizedBox(height: 24),

                // ── Homescreen Widget Card ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ActionPromptCard(
                    title: 'Homescreen Widget',
                    subtitle:
                        'Add a homescreen widget for one-tap access\nto your daily tasks and streak.',
                    buttonText: 'Add Widget',
                    onPressed: () async {
                      final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
                      if (supported) {
                        await HomeWidget.requestPinWidget(
                          androidName: 'StreakWidgetProvider',
                          name: 'StreakWidgetProvider',
                        );
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Long-press your home screen → Widgets → Meowmin Ai Diary to add it.'),
                              backgroundColor: Color(0xFF311B92),
                            ),
                          );
                        }
                      }
                    },
                    backgroundColor: const Color(0xFFE1BEE7),
                    foregroundColor: const Color(0xFF311B92),
                    icon: const Icon(
                      Icons.widgets_rounded,
                      size: 64,
                      color: Color(0xFFAB47BC),
                    ),
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

                // ── Notification Prompt ──────────────────────────────────────────────
                if (!_notificationsEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ActionPromptCard(
                      title: 'Set the reminder',
                      subtitle:
                          'Never miss your morning routine!\nSet a reminder to stay on track',
                      buttonText: 'Set Now',
                      onPressed: _handleNotificationRequest,
                      backgroundColor: const Color(0xFFFFE0B2),
                      foregroundColor: const Color(0xFF4E342E),
                      icon: const Icon(
                        Icons.notifications_active_rounded,
                        size: 64,
                        color: Color(0xFFFF7043),
                      ),
                    ),
                  ),

                const SizedBox(height: 32),

                // ── Footer Mascot ──────────────────────
                Image.asset(
                  'assets/photos/mascot/trio2.png',
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
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: tt.titleMedium?.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
