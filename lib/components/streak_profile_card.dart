import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:intl/intl.dart';
import '../services/streak_service.dart';

class StreakProfileCard extends StatefulWidget {
  const StreakProfileCard({super.key});

  @override
  State<StreakProfileCard> createState() => _StreakProfileCardState();
}

class _StreakProfileCardState extends State<StreakProfileCard> {
  int _streak = 1;
  List<bool> _last7Days = List.filled(7, false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final streak = await StreakService.getStreak();
    final days = await StreakService.getLast7Days();
    if (mounted) setState(() { _streak = streak; _last7Days = days; });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final today = DateTime.now();
    final weekDays = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return DateFormat('E').format(d).substring(0, 3);
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Streak counter card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Lottie.asset(
                      'assets/photos/elements/Streak Fire.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  Text(
                    '$_streak',
                    style: tt.displayLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                      height: 1,
                    ),
                  ),
                  Text(
                    'day streak',
                    style: tt.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Weekly tracker card - horizontally scrollable
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 12),
                    child: Text(
                      'This Week',
                      style: tt.titleSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 7,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final active = _last7Days[i];
                        final isToday = i == 6;
                        return Container(
                          width: 64,
                          decoration: BoxDecoration(
                            color: active ? cs.primaryContainer : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: active ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                weekDays[i],
                                style: tt.labelSmall?.copyWith(
                                  color: active ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Icon(
                                active ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                size: 22,
                                color: active ? cs.primary : cs.outlineVariant,
                              ),
                              if (isToday && !active)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'today',
                                    style: tt.labelSmall?.copyWith(
                                      fontSize: 9,
                                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
