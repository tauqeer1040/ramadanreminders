import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../services/streak_service.dart';
import '../services/star_service.dart';
import '../services/audio_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../screens/about_screen.dart';
import '../providers/homepage_provider.dart';
import 'journal_history_section.dart';
import 'widgets/streak_graph.dart';
import 'widgets/star_badge.dart';
import 'widgets/journal_entry_button.dart';
import 'streak_reward_dialog.dart';
import 'widgets/mascot_greeting.dart';
import 'widgets/deferred_lottie.dart';

class Homepage extends ConsumerStatefulWidget {
  const Homepage({super.key});

  @override
  ConsumerState<Homepage> createState() => HomepageState();
}

class HomepageState extends ConsumerState<Homepage> with TickerProviderStateMixin {
  Timer? _alternateTimer;
  late AnimationController _starAnimController;
  late Animation<double> _starScaleAnim;
  final _starBadgeKey = GlobalKey();
  final _journalKey = GlobalKey();
  final _scrollCtrl = ScrollController();
  late AnimationController _wobbleCtrl;
  late CurvedAnimation _wobbleAnim;
  Timer? _wobbleTimer;
  bool _belowFoldReady = false;

  @override
  void initState() {
    super.initState();
    _loadStreak();
    _loadStars();

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
      if (mounted) ref.read(homepageProvider.notifier).toggleStreak();
    });

    AuthService.authStateChanges.listen((user) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _belowFoldReady = true);
    });
  }

  Future<void> _loadStreak() async {
    final streak = await StreakService.getDisplayStreak();
    if (mounted) ref.read(homepageProvider.notifier).setStreak(streak);
    final hasReward = await StreakService.checkAndClaimPrimeReward();
    if (hasReward && mounted) {
      showStreakRewardDialog(context);
    }
  }

  Future<void> _loadStars() async {
    final stars = await StarService.loadStars();
    if (mounted) ref.read(homepageProvider.notifier).setStars(stars);
  }

  @override
  void dispose() {
    _alternateTimer?.cancel();
    _starAnimController.dispose();
    _wobbleCtrl.dispose();
    _wobbleAnim.dispose();
    _wobbleTimer?.cancel();
    super.dispose();
  }

  String _getDisplayName() {
    final user = AuthService.currentUser;
    return user?.displayName ?? user?.email?.split('@').first ?? 'friend';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homepageProvider);
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: LayoutBuilder(
            builder: (context, constraints) {
              final vh = constraints.maxHeight;
              const appbarH = 128.0;
              const writeBtnH = 120.0;
              const writeBtnTop = 56.0;
              final hoverH = max(300.0, vh - appbarH - writeBtnH - writeBtnTop);
              return SingleChildScrollView(
                controller: _scrollCtrl,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: vh),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 128,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  BackgroundMusicService().toggleMusic();
                                  setState(() {});
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Stack(
                                  children: [
                                    if (BackgroundMusicService().isMusicEnabled)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: IgnorePointer(
                                          child: Transform.scale(
                                            scale: 2,
                                            alignment: Alignment.bottomCenter,
                                            child: DeferredLottie(asset: 'assets/photos/elements/music_fly.json', fit: BoxFit.cover),
                                          ),
                                        ),
                                      ),
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: cs.primaryContainer,
                                      child: ClipOval(
                                        child: Image.asset(
                                          'assets/photos/mascot/face.webp',
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, color: cs.onSurface, size: 28),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                                    },
                                    child: AnimatedBuilder(
                                      animation: _wobbleAnim,
                                      builder: (context, child) {
                                        return Transform.rotate(
                                          angle: sin(_wobbleAnim.value * 4.5 * 2 * pi) * 0.08,
                                          child: child,
                                        );
                                      },
                                      child: Image.asset(
                                        'assets/photos/elements/meowmin.webp',
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
                              StarBadge(
                                key: _starBadgeKey,
                                streakCount: state.streakCount,
                                totalStars: state.totalStars,
                                showStreak: state.showStreak,
                                starScaleAnim: _starScaleAnim,
                              ),
                            ],
                          ),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(minHeight: hoverH),
                        child: MascotGreeting(
                          displayName: _getDisplayName(),
                          streakCount: state.streakCount,
                          customMessage: state.mascotMessage,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24).copyWith(top: 56),
                        child: JournalEntryButton(
                          displayName: _getDisplayName(),
                          starBadgeKey: _starBadgeKey,
                          onJournalSaved: (msg) {
                            _loadStars();
                            _starAnimController.forward(from: 0);
                            ref.read(homepageProvider.notifier).setMascotMessage(msg);
                          },
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (_belowFoldReady) ...[
                        JournalHistorySection(key: _journalKey, maxEntries: 3),
                        const SizedBox(height: 24),
                        StreakGraph(streak: state.streakCount, size: 220),
                        Image.asset(
                          'assets/photos/mascot/trio3.webp',
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
