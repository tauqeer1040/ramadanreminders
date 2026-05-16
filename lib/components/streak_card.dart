import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/streak_service.dart';

class StreakCard extends StatefulWidget {
  const StreakCard({super.key});

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard> {
  int _streak = 1;
  List<bool> _last7Days = List.filled(7, false);
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final streak = await StreakService.getStreak();
    final days = await StreakService.getLast7Days();
    if (mounted) {
      setState(() {
        _streak = streak;
        _last7Days = days;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final today = DateTime.now();
    final weekDays = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return DateFormat('E').format(d).substring(0, 1).toLowerCase();
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cs.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Streak number + image
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                children: [
                  Image.asset(
                    'assets/photos/elements/streak.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.local_fire_department_rounded,
                      size: 40,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$_streak',
                        style: tt.displaySmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: cs.onSurface,
                          height: 1,
                        ),
                      ),
                      Text(
                        _streak == 1 ? 'day streak' : 'day streak',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Divider
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),

            // 7-day activity graph
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (i) {
                  final active = _last7Days[i];
                  final isToday = i == 6;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active
                              ? cs.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: active ? cs.primary : cs.outlineVariant,
                            width: active ? 0 : 1.5,
                          ),
                        ),
                        child: isToday && !active
                            ? Center(
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: cs.primary.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        weekDays[i],
                        style: tt.labelSmall?.copyWith(
                          color: active ? cs.primary : cs.onSurfaceVariant,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
    );
  }
}
