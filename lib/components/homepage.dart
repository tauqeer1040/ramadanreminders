import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/streak_service.dart';
import '../services/journal_service.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import '../screens/about_screen.dart';
import 'widgets/duo_button.dart';
import 'journal_bottom_sheet.dart';
import 'journal_history_section.dart';
import 'stats_card.dart';
import '../theme/app_theme.dart';


class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => HomepageState();
}

class HomepageState extends State<Homepage> with TickerProviderStateMixin {
  int _streakCount = 1;
  int _totalStars = 0;
  bool _showStreak = true;
  Timer? _alternateTimer;
  late AnimationController _starAnimController;
  late Animation<double> _starScaleAnim;
  late ConfettiController _confettiController;
  final _starBadgeKey = GlobalKey();
  final _writeBtnKey = GlobalKey();
  final _journalKey = GlobalKey();
  final _scrollCtrl = ScrollController();
  bool _showStarTrail = false;
  Offset? _trailStart, _trailEnd;
  late AnimationController _trailController;
  late AnimationController _wobbleCtrl;
  late CurvedAnimation _wobbleAnim;
  Timer? _wobbleTimer;

  @override
  void initState() {
    super.initState();
    _loadStreak();
    loadStars();

    _wobbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _wobbleAnim = CurvedAnimation(
      parent: _wobbleCtrl,
      curve: Curves.easeInOutSine,
    );
    _wobbleTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _wobbleCtrl.forward(from: 0),
    );
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _trailController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showStarTrail = false);
      }
    });

    _starAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _starScaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.85), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _starAnimController, curve: Curves.easeInOut));

    _alternateTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() => _showStreak = !_showStreak);
    });

    // Listen to Auth state to refresh the dynamic avatar automatically!
    AuthService.authStateChanges.listen((user) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadStreak() async {
    final streak = await StreakService.getStreak();
    if (mounted) setState(() => _streakCount = streak);
  }

  @override
  void dispose() {
    _alternateTimer?.cancel();
    _starAnimController.dispose();
    _wobbleCtrl.dispose();
    _wobbleAnim.dispose();
    _wobbleTimer?.cancel();
    _confettiController.dispose();
    _trailController.dispose();
    super.dispose();
  }

  Future<void> loadStars() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _totalStars = prefs.getInt('total_stars') ?? 0);
  }

  Future<bool> _tryIncrementStars(int amount, String cooldownKey) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt(cooldownKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastTime < 43200000) return false; // 12 hours
    await prefs.setInt(cooldownKey, now);
    final current = prefs.getInt('total_stars') ?? 0;
    final updated = current + amount;
    await prefs.setInt('total_stars', updated);
    if (mounted) {
      setState(() => _totalStars = updated);
      _starAnimController.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
    return true;
  }

  Future<void> _onJournalSaved() async {
    HapticFeedback.mediumImpact();
    // Capture positions for star trail
    final startCtx = _writeBtnKey.currentContext;
    final endCtx = _starBadgeKey.currentContext;
    if (startCtx != null && endCtx != null && mounted) {
      final startBox = startCtx.findRenderObject() as RenderBox;
      final endBox = endCtx.findRenderObject() as RenderBox;
      _trailStart = startBox.localToGlobal(startBox.size.center(Offset.zero));
      _trailEnd = endBox.localToGlobal(endBox.size.center(Offset.zero));
      setState(() => _showStarTrail = true);
      _trailController.forward(from: 0);
    }

    _tryIncrementStars(10, 'last_journal_star_time');
    _confettiController.play();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 60),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          backgroundColor: Colors.transparent,
          duration: const Duration(seconds: 2),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Center(
                  child: Text('Journal saved ✨'),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  String _getDisplayName() {
    final user = AuthService.currentUser;
    return user?.displayName ?? user?.email?.split('@').first ?? 'friend';
  }

  void _scrollToJournalHistory() {
    final ctx = _journalKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, alignment: 0.0, duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Stack(
      children: [
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final vh = constraints.maxHeight;
              const appbarH = 128.0;
              const writeBtnH = 72.0;
              const writeBtnBottom = 48.0;
              final hoverH = max(100.0, vh - appbarH - writeBtnH - writeBtnBottom);
              return SingleChildScrollView(
              controller: _scrollCtrl,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: vh),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top Bar: Profile Avatar · App Title · Streak/Score ─────────
                SizedBox(
                  height: 128,
                  child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // Profile avatar
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AboutScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: cs.primaryContainer,
                          child: ClipOval(
                            child: Image.asset(
                              'assets/photos/mascot/hi.webp',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, color: cs.onSurface, size: 28),
                            ),
                          ),
                        ),
                      ),
                      // App title
                      Expanded(
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              Superwall.shared.registerPlacement(
                                'campaign_trigger',
                              );
                            },
                            child: AnimatedBuilder(
                              animation: _wobbleAnim,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: sin(
                                        _wobbleAnim.value * 4.5 * 2 * pi,
                                      ) *
                                      0.08,
                                  child: child,
                                );
                              },
                              child: Image.asset(
                                'assets/photos/elements/meowmin.png',
                                width: 120,
                                height: 80,
                                fit: BoxFit.contain,
                              ).animate().shimmer(
                                duration: 2500.ms,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Alternating streak / star badge
                      AnimatedSwitcher(
                          key: _starBadgeKey,
                          duration: const Duration(milliseconds: 600),
                          transitionBuilder: (child, animation) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.3),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              )),
                              child: FadeTransition(opacity: animation, child: child),
                            );
                          },
                          child: _showStreak
                            ? Row(
                                key: const ValueKey('streak'),
                                children: [
                                  SizedBox(
                                    width: 44,
                                    height: 44,
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
                                      fontSize: 20,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                key: const ValueKey('stars'),
                                children: [
                                  ScaleTransition(
                                    scale: _starScaleAnim,
                                    child: const Icon(
                                      Icons.star_rounded,
                                      color: AppTheme.starGold,
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ScaleTransition(
                                    scale: _starScaleAnim,
                                    child: Text(
                                      '$_totalStars',
                                      style: tt.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.starGold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
        ),
        if (_showStarTrail && _trailStart != null && _trailEnd != null)
          IgnorePointer(
            child: _StarTrail(
              start: _trailStart!,
              end: _trailEnd!,
              controller: _trailController,
            ),
          ),
      ],
                  ),
                ),
                ),

                // ── Mascot Greeting ────────────────────────────────────────────
                SizedBox(
                  height: hoverH,
                  child: _MascotGreeting(
                    displayName: _getDisplayName(),
                    streakCount: _streakCount,
                  ),
                ),

                // ── Write Button ───────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.only(left: 24, right: 24, bottom: writeBtnBottom),
                  child: DuoButton(
                    key: _writeBtnKey,
                    onPressed: () async {
                      final limit = await JournalService.isGuestLimitReached();
                      if (limit && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Free Trial limit reached! Tap your Profile to sign up securely and unlock unlimited journals."),
                            duration: Duration(seconds: 4),
                          ),
                        );
                        return;
                      }
                      if (context.mounted) {
                        final scrollCtrl = ScrollController();
                        final wrote = await showModalBottomSheet<bool>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          backgroundColor: Colors.transparent,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => JournalBottomSheet(
                            scrollController: scrollCtrl,
                          ),
                        );
                        scrollCtrl.dispose();
                        if (wrote == true) _onJournalSaved();
                      }
                    },
                    backgroundColor: AppTheme.neonPurple,
                    depthColor: AppTheme.neonPurple.withValues(alpha: 0.7),
                    radius: 20,
                    height: 72,
                    sfxType: DuoSfxType.positive,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_rounded, color: AppTheme.starWhite, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Write',
                          style: TextStyle(
                            color: AppTheme.starWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Journal History ───────────────────────────────────────
                JournalHistorySection(key: _journalKey, maxEntries: 3),

                const SizedBox(height: 24),

                // ── Stats Card ────────────────────────────────────────────
                StatsCard(onTapEntries: _scrollToJournalHistory),

                const SizedBox(height: 28),

                SizedBox(height: max(0, vh - 400)),

                // ── Title ─────────────────────────────────────────────────────────────
                //     '3 tasks for you',
                //     textAlign: TextAlign.center,
                //     style: tt.headlineLarge?.copyWith(
                //       fontWeight: FontWeight.w900,
                //       color: cs.onSurface,
                //       height: 1.2,
                //       fontSize: 28,
                //     ),
                //   ),
                // ),

                // const SizedBox(height: 24),

                // // ── Bounded Task Carousel ─────────────────────────────────────────────
                // SizedBox(
                //   height: 380,
                //   child: const TaskCarousel(),
                // ),

                // const SizedBox(height: 24),

                const SizedBox(height: 32),

                // ── Footer Mascot ──────────────────────
                Image.asset(
                  'assets/photos/mascot/trio3.png',
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                ),
                // const SizedBox(height: 32),
              ],
            ),
          ),
          );
        },
      ),
    ),
        Positioned.fill(
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 24,
              emissionFrequency: 0.06,
              maxBlastForce: 35,
              minBlastForce: 10,
              colors: const [
                Colors.blue,
                Colors.pink,
                Colors.yellow,
                Colors.green,
                Colors.purple,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StarTrail extends StatelessWidget {
  final Offset start;
  final Offset end;
  final AnimationController controller;

  const _StarTrail({
    required this.start,
    required this.end,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final rng = Random();
    final stars = List.generate(18, (i) {
      final t = i / 18;
      final delay = t * 0.25;
      final lateral = Offset(
        (rng.nextDouble() - 0.5) * 24,
        (rng.nextDouble() - 0.5) * 24,
      );
      return _StarParticle(
        delay: delay,
        lateral: lateral,
      );
    });

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final progress = controller.value;
        return Stack(
          children: stars.map((p) {
            final p0 = start;
            final p3 = end;
            final cp1 = Offset(p0.dx + 40, p0.dy + 100);
            final cp2 = Offset(p3.dx - 80, p3.dy + 160);

            final raw = (progress - p.delay).clamp(0.0, 1.0) / (1 - p.delay);
            final tCurve = Curves.easeInOut.transform(raw.clamp(0.0, 1.0));

            final pos = _cubicBezier(p0, cp1, cp2, p3, tCurve) + p.lateral;

            final opacity = (tCurve < 0.1)
                ? tCurve / 0.1
                : (tCurve > 0.85)
                    ? (1 - tCurve) / 0.15
                    : 1.0;

            return Positioned(
              left: pos.dx - 10,
              top: pos.dy - 10,
              child: Opacity(
                opacity: opacity * (raw < 0 ? 0 : 1),
                child: Icon(
                  Icons.star_rounded,
                  color: AppTheme.starGold,
                  size: 20,
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Offset _cubicBezier(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final mt = 1 - t;
    return p0 * (mt * mt * mt) +
        p1 * (3 * mt * mt * t) +
        p2 * (3 * mt * t * t) +
        p3 * (t * t * t);
  }
}

class _StarParticle {
  final double delay;
  final Offset lateral;

  const _StarParticle({required this.delay, required this.lateral});
}

class _MascotGreeting extends StatefulWidget {
  final String displayName;
  final int streakCount;

  const _MascotGreeting({
    required this.displayName,
    required this.streakCount,
  });

  @override
  State<_MascotGreeting> createState() => _MascotGreetingState();
}

class _MascotGreetingState extends State<_MascotGreeting>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnim;
  late String _currentMessage;
  static const _bubbleAsset = 'assets/chatbubbles/1 (3).png';

  static const _messageTemplates = [
    'Hey {name}, how are we feeling today?',
    'Hey {name}, I had a busy day! I caught a mouse and made you your scratch cards, take a look!',
    "Masha'Allah {name}, you're on a {streak}-day streak! Keep it going!",
    'Purring while I wait for you to write in your journal, {name}.',
    'Ready for today\'s reflection, {name}?',
    '{name}, the stars are aligned for a beautiful day ahead.',
    'Meow! Let\'s make today amazing, {name}!',
    'I\'ve been working on special insights just for you, {name}!',
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _pickRandomMessage();
  }

  void _pickRandomMessage() {
    final template =
        _messageTemplates[Random().nextInt(_messageTemplates.length)];
    _currentMessage = template
        .replaceAll('{name}', widget.displayName)
        .replaceAll('{streak}', '${widget.streakCount}');
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: child,
        );
      },
      child: Column(
      children: [
        // Speech bubble with chat tail
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _pickRandomMessage());
            },
            child: Container(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_bubbleAsset),
                  fit: BoxFit.fill,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(44, 34, 44, 58),
                child: Text(
                  _currentMessage,
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(
                    color: AppTheme.starWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Floating mascot with gradient glow
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.neonPurple.withValues(alpha: 0.25),
                    AppTheme.neonPurple.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Image.asset(
              'assets/photos/mascot/hi.webp',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.auto_awesome_rounded,
                color: Theme.of(context).colorScheme.onSurface,
                size: 80,
              ),
            ),
          ],
        ),
      ],
    ),
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
