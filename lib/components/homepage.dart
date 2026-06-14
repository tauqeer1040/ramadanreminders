import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/streak_service.dart';
import '../services/journal_service.dart';
// import './task_carousel.dart';  // kept for later use
import 'package:lottie/lottie.dart';
import 'about_bottom_sheet.dart';
import 'widgets/duo_button.dart';
import 'journal_bottom_sheet.dart';
import 'mood_check_in_bottom_sheet.dart';
import 'journal_history_section.dart';
import 'stats_card.dart';
import '../theme/app_theme.dart';
import 'package:flutter_confetti/flutter_confetti.dart';


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
  bool _showStarTrail = false;
  Offset? _trailStart, _trailEnd;
  late AnimationController _trailController;

  @override
  void initState() {
    super.initState();
    _loadStreak();
    loadStars();

    _confettiController = ConfettiController();
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
    _confettiController.kill();
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
    _confettiController.launch();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Journal saved ✨'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _startVoiceInput() async {
    final limit = await JournalService.isGuestLimitReached();
    if (limit && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Free Trial limit reached! Tap your Profile to sign up securely and unlock unlimited journals."),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final speech = SpeechToText();
    final available = await speech.initialize();
    if (!available || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition is not available on this device.'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VoiceRecordingSheet(speech: speech),
    );

    if (text != null && text.trim().isNotEmpty && mounted) {
      final wrote = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => JournalBottomSheet(initialText: text),
      );
      if (wrote == true) _onJournalSaved();
    }
  }

  String _getDisplayName() {
    final user = AuthService.currentUser;
    return user?.displayName ?? user?.email?.split('@').first ?? 'friend';
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
              return SingleChildScrollView(
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
                          child: Image.asset(
                            'assets/photos/elements/meowmin.png',
                            height: 96,
                            fit: BoxFit.contain,
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

                const SizedBox(height: 16),

                // ── Mascot Greeting ────────────────────────────────────────────
                _MascotGreeting(
                  displayName: _getDisplayName(),
                  streakCount: _streakCount,
                ),

                const SizedBox(height: 8),

                // ── Write / Voice Buttons ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    children: [
                      Expanded(
                        key: _writeBtnKey,
                        child: DuoButton(
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
                              final wrote = await showModalBottomSheet<bool>(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                backgroundColor: Colors.transparent,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (_) => const JournalBottomSheet(),
                              );
                              if (wrote == true) _onJournalSaved();
                            }
                          },
                          backgroundColor: AppTheme.neonPurple,
                          depthColor: AppTheme.neonPurple.withValues(alpha: 0.7),
                          radius: 20,
                          height: 72,
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: DuoButton(
                          onPressed: _startVoiceInput,
                          backgroundColor: AppTheme.neonPurple,
                          depthColor: AppTheme.neonPurple.withValues(alpha: 0.7),
                          radius: 20,
                          height: 72,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.mic_rounded, color: AppTheme.starWhite, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Voice',
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
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Mood Check-in Button ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: DuoButton(
                    onPressed: () async {
                      final entry = await showModalBottomSheet<MoodEntry>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        backgroundColor: Colors.transparent,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        builder: (_) => const MoodCheckInBottomSheet(),
                      );
                      if (entry != null && context.mounted) {
                        // Persist the mood check-in count
                        final prefs = await SharedPreferences.getInstance();
                        final prev = prefs.getInt('mood_checkin_count') ?? 0;
                        await prefs.setInt('mood_checkin_count', prev + 1);
                        final key = 'mood_${entry.timestamp.toIso8601String().substring(0, 10)}';
                        await prefs.setString(key, entry.value.toStringAsFixed(2));

                        _tryIncrementStars(5, 'last_mood_star_time');
                        _confettiController.launch();

                        final label = moodLabel(entry.value);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Mood logged: $label ✨'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: moodColors(entry.value)[1],
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    backgroundColor: const Color(0xFF2D2040),
                    depthColor: const Color(0xFF1A1228),
                    radius: 20,
                    height: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sentiment_satisfied_alt_rounded,
                            color: AppTheme.starWhite, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Mood Check-in',
                          style: TextStyle(
                            color: AppTheme.starWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // ── Journal History ───────────────────────────────────────
                const JournalHistorySection(maxEntries: 3),

                const SizedBox(height: 28),

                // ── Stats Card ────────────────────────────────────────────
                const StatsCard(),

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
          );
        },
      ),
    ),
        IgnorePointer(
          child: Confetti(
            controller: _confettiController,
            options: const ConfettiOptions(
              particleCount: 80,
              spread: 360,
              startVelocity: 25,
              decay: 0.95,
              gravity: 0.3,
              scalar: 1.5,
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

class _VoiceRecordingSheet extends StatefulWidget {
  final SpeechToText speech;

  const _VoiceRecordingSheet({required this.speech});

  @override
  State<_VoiceRecordingSheet> createState() => _VoiceRecordingSheetState();
}

class _VoiceRecordingSheetState extends State<_VoiceRecordingSheet>
    with SingleTickerProviderStateMixin {
  String _text = '';
  bool _isListening = true;
  bool _hasResult = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startListening();
  }

  void _startListening() {
    widget.speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _text = result.recognizedWords;
            _hasResult = result.hasConfidenceRating && result.confidence > 0;
            _isListening = true;
          });
        }
      },
      onStatus: (status) {
        if (mounted) {
          setState(() {
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
            } else if (status == 'error') {
              _isListening = false;
            }
          });
        }
      },
      listenFor: const Duration(seconds: 120),
      pauseFor: const Duration(seconds: 6),
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.continuousDictation,
        partialResults: true,
      ),
      localeId: 'en_US',
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    widget.speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      height: 340,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1028),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            // Mic icon with pulse
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                return Transform.scale(
                  scale: _isListening ? _pulseAnim.value : 1.0,
                  child: child,
                );
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isListening
                      ? AppTheme.neonPurple.withValues(alpha: 0.20)
                      : Colors.white.withValues(alpha: 0.06),
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_off,
                  size: 40,
                  color: _isListening
                      ? AppTheme.neonPurple
                      : Colors.white.withValues(alpha: 0.40),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isListening ? 'Listening...' : 'Tap done when finished',
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.80),
              ),
            ),
            if (_hasResult) ...[
              const SizedBox(height: 6),
              Text(
                'Confidence: high',
                style: tt.labelSmall?.copyWith(
                  color: AppTheme.neonGreen.withValues(alpha: 0.60),
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Transcription preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                _text.isEmpty ? '(speak now)' : _text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(
                  color: _text.isEmpty
                      ? Colors.white.withValues(alpha: 0.30)
                      : Colors.white.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () {
                    widget.speech.cancel();
                    Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.60),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    widget.speech.stop();
                    Navigator.pop(context, _text);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.neonPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14,
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
