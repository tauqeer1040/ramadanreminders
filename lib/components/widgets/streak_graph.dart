import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import '../../theme/app_theme.dart';

class StreakGraph extends StatefulWidget {
  final int streak;
  final double size;

  const StreakGraph({
    super.key,
    required this.streak,
    this.size = 280,
  });

  @override
  State<StreakGraph> createState() => _StreakGraphState();
}

class _StreakGraphState extends State<StreakGraph> with SingleTickerProviderStateMixin {
  late final AnimationController _popController;
  late final Animation<double> _popScale;
  bool _hintDismissed = false; // To hide the subtitle after tap

  @override
  void initState() {
    super.initState();
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _popScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _popController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  bool _isPrime(int n) {
    if (n <= 1) return false;
    if (n <= 3) return true;
    if (n % 2 == 0 || n % 3 == 0) return false;
    for (int i = 5; i * i <= n; i = i + 6) {
      if (n % i == 0 || n % (i + 2) == 0) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // We'll show a window of 7 days around the current streak
    int startDay = (widget.streak - 3).clamp(1, double.infinity).toInt();
    if (widget.streak <= 4) startDay = 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lottie Fire Icon
        SizedBox(
          height: widget.size * 0.8,
          child: Lottie.asset(
            'assets/logo/Streak Fire.json',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.local_fire_department_rounded,
              color: AppTheme.starGold,
              size: 64,
            ),
          ),
        ),
        
        // Streak Number
        Transform.translate(
          offset: Offset(0, -widget.size * 0.20),
          child: Column(
            children: [
              Text(
                '${widget.streak}',
                style: TextStyle(
                  color: AppTheme.starWhite,
                  fontSize: widget.size * 0.25,
                  fontWeight: FontWeight.w900,
                  height: 0.9,
                ),
              ),
              const Text(
                'day streak!',
                style: TextStyle(
                  color: AppTheme.starWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 7-Day Graph Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.starWhite.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutBack,
            alignment: Alignment.topCenter,
            child: Column(
            children: [
              // Days Row (Scrollable)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(7, (index) {
                      final dayNum = startDay + index;
                      final bool isCurrent = dayNum == widget.streak;
                      final bool isPast = dayNum < widget.streak;
                      final bool isPrime = _isPrime(dayNum);
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _buildDayColumn(dayNum, isCurrent, isPast, isPrime, widget.streak),
                      );
                    }),
                  ),
                ),
              ),
              // Animated Hint Section
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  );
                },
                child: _hintDismissed
                    ? const SizedBox.shrink()
                    : Column(
                        key: const ValueKey('hint_active'),
                        children: [
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () {
                              if (_hintDismissed) return;
                              _popController.forward().then((_) {
                                _popController.reverse().then((_) {
                                  if (mounted) setState(() => _hintDismissed = true);
                                });
                              });

                              Confetti.launch(
                                context,
                                options: ConfettiOptions(
                                  particleCount: 30,
                                  spread: 40,
                                  y: 0.6,
                                  scalar: 0.8,
                                  colors: const [AppTheme.starGold, AppTheme.starWhite],
                                ),
                              );
                            },
                            child: ScaleTransition(
                              scale: _popScale,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppTheme.starGold.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.starGold.withValues(alpha: 0.2), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: AppTheme.starGold, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Don't miss the ? days, they give you limited edition secret cards which can't be unlocked if missed. Lost forever. 🔥",
                                        style: TextStyle(
                                          color: AppTheme.starWhite.withValues(alpha: 1.0),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

  String _getDayLetter(int dayNum, int currentStreak) {
    // Calculate the date for this streak day
    // Streak Day `currentStreak` is `DateTime.now()`
    final delta = dayNum - currentStreak;
    final date = DateTime.now().add(Duration(days: delta));
    final weekday = date.weekday; // 1 = Mon, 7 = Sun
    
    const letters = ['', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return letters[weekday];
  }

  Widget _buildDayColumn(int dayNum, bool isCurrent, bool isPast, bool isPrime, int currentStreak) {
    Color labelColor = AppTheme.ghostSilver;
    if (isCurrent) labelColor = AppTheme.starWhite;
    
    final bool isCompleted = isPast || isCurrent;
    
    return Column(
      children: [
        Text(
          _getDayLetter(dayNum, currentStreak),
          style: TextStyle(
            color: labelColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 38,
          height: 38,
          child: Center(
            child: isPrime 
                ? (isCompleted 
                    ? const Icon(Icons.auto_awesome_rounded, color: Color(0xFF58CC02), size: 24)
                    : GestureDetector(
                        onTap: () => setState(() => _hintDismissed = !_hintDismissed),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.starWhite.withValues(alpha: 0.1),
                            border: Border.all(color: AppTheme.starWhite.withValues(alpha: 0.15), width: 1.5),
                          ),
                          child: const Center(
                            child: Text('?', style: TextStyle(color: AppTheme.starGold, fontSize: 16, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ))
                : (isCompleted || dayNum == 1)
                    ? Lottie.asset(
                        'assets/logo/Streak Fire.json',
                        width: 44,
                        height: 44,
                        fit: BoxFit.contain,
                      )
                    : Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.starWhite.withValues(alpha: 0.1),
                          border: Border.all(color: AppTheme.starWhite.withValues(alpha: 0.15), width: 1.5),
                        ),
                      ),
          ),
        ),
      ],
    );
  }
}
