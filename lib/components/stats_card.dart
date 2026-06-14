import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/journal_service.dart';
import '../services/streak_service.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _StatsData {
  final int totalEntries;
  final int streakDays;
  final int totalWords;
  final int savedFavorites;
  final int totalStars;
  final int moodCheckIns;
  final int quranDays;
  final List<int> monthlyEntries;

  const _StatsData({
    required this.totalEntries,
    required this.streakDays,
    required this.totalWords,
    required this.savedFavorites,
    required this.totalStars,
    required this.moodCheckIns,
    required this.quranDays,
    required this.monthlyEntries,
  });
}

Future<_StatsData> _loadStats() async {
  // Run all I/O in parallel
  final results = await Future.wait([
    JournalService.getAllLocalJournals(),
    StreakService.getStreak(),
    FavoritesService.getFavorites(),
    SharedPreferences.getInstance(),
  ]);

  final journals = results[0] as List<Map<String, String>>;
  final streak = results[1] as int;
  final favorites = results[2] as List<FavoriteItem>;
  final prefs = results[3] as SharedPreferences;

  final now = DateTime.now();
  final monthly = List<int>.filled(12, 0);
  int totalWords = 0;

  for (final j in journals) {
    final text = j['text'] ?? '';
    final dateStr = j['date'] ?? '';

    // Count words
    if (text.trim().isNotEmpty) {
      totalWords +=
          text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }

    // Monthly bucketing (current year only)
    try {
      final d = DateTime.parse(dateStr);
      if (d.year == now.year) monthly[d.month - 1]++;
    } catch (_) {}
  }

  final quranDays = prefs.getKeys().where((k) => k.startsWith('quran_revealed_')).length;

  return _StatsData(
    totalEntries: journals.length,
    streakDays: streak,
    totalWords: totalWords,
    savedFavorites: favorites.length,
    totalStars: prefs.getInt('total_stars') ?? 0,
    moodCheckIns: prefs.getInt('mood_checkin_count') ?? 0,
    quranDays: quranDays,
    monthlyEntries: monthly,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly bar chart
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlyBarChart extends StatelessWidget {
  final List<int> counts;
  final Color barColor;
  final int currentMonth;
  final double barMaxHeight;
  final double labelFontSize;

  const _MonthlyBarChart({
    required this.counts,
    required this.barColor,
    required this.currentMonth,
    this.barMaxHeight = 44,
    this.labelFontSize = 8,
  });

  int _predictedFor(int monthIndex) {
    final actualMonths = counts.take(currentMonth + 1).toList();
    final nonZero = actualMonths.where((v) => v > 0).toList();
    final avg = nonZero.isEmpty ? 3.0 : nonZero.reduce((a, b) => a + b) / nonZero.length;
    final monthsAhead = monthIndex - currentMonth;
    return (avg * pow(1.08, monthsAhead)).round();
  }

  @override
  Widget build(BuildContext context) {
    final all = List<int>.generate(12, (i) {
      if (i <= currentMonth) return counts[i];
      return _predictedFor(i);
    });
    final maxVal = all.reduce(max).clamp(1, 9999999);
    const monthLabels = [
      'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(12, (i) {
        final isNow = i == currentMonth;
        final isFuture = i > currentMonth;
        final value = isFuture ? all[i] : counts[i];
        final fraction = value / maxVal;
        final barH = (fraction * barMaxHeight).clamp(2.0, barMaxHeight);

        Color barColorResolved;
        if (isNow) {
          barColorResolved = barColor;
        } else if (isFuture) {
          barColorResolved = barColor.withValues(alpha: 0.3);
        } else {
          barColorResolved = barColor.withValues(alpha: counts[i] > 0 ? 0.55 : 0.12);
        }

        return SizedBox(
          width: 12,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 350 + i * 35),
                curve: Curves.easeOutCubic,
                height: barH,
                decoration: BoxDecoration(
                  color: barColorResolved,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                monthLabels[i],
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight:
                      isNow ? FontWeight.w800 : FontWeight.w400,
                  color: isNow
                      ? barColor
                      : Colors.white.withValues(alpha: 0.4),
                  height: 1,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual stat tile
// ─────────────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.22), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 17),
            const SizedBox(height: 8),
            Text(
              value,
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppTheme.starWhite,
                fontSize: 20,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: AppTheme.ghostSilver,
                fontWeight: FontWeight.w500,
                fontSize: 10.5,
                height: 1.2,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(
                sub!,
                style: tt.labelSmall?.copyWith(
                  color: color.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                  height: 1,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _fmtWords(int n) {
  if (n >= 1000) {
    final k = n / 1000;
    return '${k.toStringAsFixed(k < 10 ? 1 : 0)}K';
  }
  return '$n';
}

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

class StatsCard extends StatefulWidget {
  const StatsCard({super.key});

  /// Call this to trigger a data refresh (e.g. after a new journal is written).
  static void refresh(BuildContext context) {
    context.findAncestorStateOfType<_StatsCardState>()?.refresh();
  }

  @override
  State<StatsCard> createState() => _StatsCardState();
}

class _StatsCardState extends State<StatsCard>
    with SingleTickerProviderStateMixin {
  late Future<_StatsData> _future;
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
  }

  void _load() {
    _future = _loadStats();
    _future.then((_) {
      if (mounted) _fadeCtrl.forward(from: 0);
    });
  }

  void refresh() {
    if (mounted) setState(_load);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
          child: Row(
            children: [
              Text(
                'Stats',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.starWhite,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.bar_chart_rounded,
                size: 18,
                color: AppTheme.neonPurple.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),

        FutureBuilder<_StatsData>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return _skeleton();
            }
            if (snap.hasError || !snap.hasData) return const SizedBox.shrink();
            return FadeTransition(
              opacity: _fade,
              child: _card(context, snap.data!),
            );
          },
        ),
      ],
    );
  }

  Widget _skeleton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.neonPurple.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, _StatsData data) {
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final yearCount = data.monthlyEntries.reduce((a, b) => a + b);
    const accent = AppTheme.neonPurple;
    final quranPct = data.streakDays > 0 ? (data.quranDays * 100 ~/ data.streakDays) : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.09),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$yearCount',
                      style: tt.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.starWhite,
                        fontSize: 56,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Entries',
                      style: tt.bodyMedium?.copyWith(
                        color: AppTheme.ghostSilver,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'This Year · ${now.year}',
                      style: tt.labelSmall?.copyWith(
                        color: accent.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 168,
                  height: 68,
                  child: _MonthlyBarChart(
                    counts: data.monthlyEntries,
                    barColor: accent,
                    currentMonth: now.month - 1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.07),
            indent: 20,
            endIndent: 20,
          ),

          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Day Streak',
                          value: '${data.streakDays}',
                          sub: 'days',
                          icon: Icons.local_fire_department_rounded,
                          color: const Color(0xFFFF6B35),
                          onTap: () => _showStatDetail(context, data, 0),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          label: 'All Entries',
                          value: '${data.totalEntries}',
                          sub: 'all time',
                          icon: Icons.edit_note_rounded,
                          color: accent,
                          onTap: () => _showStatDetail(context, data, 1),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          label: 'Words',
                          value: _fmtWords(data.totalWords),
                          sub: 'written',
                          icon: Icons.text_fields_rounded,
                          color: const Color(0xFF26C6DA),
                          onTap: () => _showStatDetail(context, data, 2),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Saved',
                          value: '${data.savedFavorites}',
                          sub: 'favourites',
                          icon: Icons.bookmark_rounded,
                          color: const Color(0xFF26A69A),
                          onTap: () => _showStatDetail(context, data, 3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          label: 'Stars',
                          value: '${data.totalStars}',
                          sub: 'earned',
                          icon: Icons.star_rounded,
                          color: AppTheme.starGold,
                          onTap: () => _showStatDetail(context, data, 4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatTile(
                          label: 'Moods',
                          value: '${data.moodCheckIns}',
                          sub: 'logged',
                          icon: Icons.sentiment_satisfied_alt_rounded,
                          color: const Color(0xFF66BB6A),
                          onTap: () => _showStatDetail(context, data, 5),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _StatTile(
                  label: 'Quran Read',
                  value: '$quranPct%',
                  sub: '${data.quranDays} days',
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFF7E57C2),
                  onTap: () => _showStatDetail(context, data, 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStatDetail(BuildContext context, _StatsData data, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => _StatStorySheet(data: data, initialIndex: index),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tweet-style Stat Story Carousel
// ─────────────────────────────────────────────────────────────────────────────

String _tweetFor(int index, _StatsData data) {
  final d = data.streakDays;
  final e = data.totalEntries;
  final w = data.totalWords;
  final f = data.savedFavorites;
  final s = data.totalStars;
  final m = data.moodCheckIns;
  final q = data.quranDays;

  switch (index) {
    case 0:
      if (d == 0) return "You just started your streak journey. Day 1 — every streak begins with a single step. 🔥";
      if (d >= 30) return "You've held a $d-day streak! Over a month of unwavering consistency. Your dedication is truly inspiring. 🔥💪";
      if (d >= 14) return "You're on a $d-day streak! Two weeks of showing up for yourself. This is becoming a powerful habit. 🔥📝";
      if (d >= 7) return "You're on a $d-day streak! A full week of consistency. You're proving that showing up daily makes all the difference. 🔥";
      return "You're on a $d-day streak! Each day you show up, you're building momentum. Consistency over perfection. 🔥";
    case 1:
      if (e == 0) return "You've written 0 entries so far. Every journal starts with a single page — yours is waiting. 📝";
      if (e >= 100) return "You've written $e entries! A century of thoughts, reflections, and growth. Your journal is a treasure. ✨📝";
      if (e >= 50) return "You've written $e entries! Your journal is thriving — half a hundred moments captured. Every page tells a story. 📝";
      if (e >= 10) return "You've written $e entries! Your journal is growing into something meaningful. Each entry is a snapshot of your journey.";
      return "You've written $e entr${e == 1 ? 'y' : 'ies'} so far. Keep going — each one captures a moment of your Ramadan journey. 📝";
    case 2:
      if (w == 0) return "You haven't written any words yet. But every masterpiece starts with a single word. ✍️";
      if (w >= 10000) return "You've written ${_fmtWords(w)} words! That's a short novel's worth of reflections. Your voice has volume and depth. 📚✨";
      if (w >= 1000) return "You've written ${_fmtWords(w)} words! That's essay territory. Your thoughts have range and your voice is finding its rhythm. 📚";
      return "You've written ${_fmtWords(w)} words. Every word you write is a step forward in your journey. ✍️";
    case 3:
      if (f == 0) return "You haven't saved any entries yet. Bookmark the ones that resonate with your heart. 📖";
      if (f >= 20) return "You've saved $f favourites! A rich anthology of your most meaningful moments. Your personal treasury of reflections. 📖❤️";
      if (f >= 10) return "You've saved $f favourites! You're curating a collection of what speaks to your soul. 📖";
      return "You've saved $f entr${f == 1 ? 'y' : 'ies'}. The ones that truly resonate — you knew to keep them close. 📖";
    case 4:
      if (s == 0) return "You haven't earned any stars yet. Write entries and log moods to make your sky shine. ⭐";
      if (s >= 100) return "You've earned $s stars! A whole galaxy of achievements. Each star represents a moment of growth. ⭐🌌";
      if (s >= 50) return "You've earned $s stars! Halfway to a galaxy — your dedication lights up the sky. ⭐✨";
      if (s >= 10) return "You've earned $s stars! Your sky is getting brighter with every achievement. ⭐";
      return "You've earned $s star${s == 1 ? '' : 's'}! Each one shines for a moment of growth and reflection. ⭐";
    case 5:
      if (m == 0) return "You haven't logged a mood yet. After each entry, check in — your emotional patterns matter. 🎭";
      if (m >= 30) return "You've logged $m moods! Rich emotional data — you're deeply in tune with yourself. Your self-awareness is a superpower. 🎭💜";
      if (m >= 10) return "You've logged $m moods! Patterns are emerging — you can see the rhythm of your heart. 🎭";
      return "You've logged $m mood${m == 1 ? '' : 's'}. Awareness grows with every check-in — you're learning what lifts you. 🎭";
    case 6:
      if (q == 0) return "You haven't explored the Quran page yet. Open an ayah card and let the words of Allah illuminate your heart. 📖🌙";
      if (q >= 30) return "You've engaged with the Quran on $q different days! Over a month of divine reflection. The words of Allah are becoming part of your daily life. 📖🤲";
      if (q >= 14) return "You've engaged with the Quran on $q days! Two weeks of ayahs and insights. Your connection to the Book of Allah is deepening beautifully. 📖🌙";
      if (q >= 7) return "You've engaged with the Quran on $q days! A full week of divine wisdom. Your heart is opening to the words of the Most Merciful. 📖✨";
      return "You've engaged with the Quran on $q day${q == 1 ? '' : 's'}. Each ayah you read brings you closer to the wisdom of the Qur'an. 📖🤲";
    default:
      return "";
  }
}

class _StatStorySheet extends StatefulWidget {
  final _StatsData data;
  final int initialIndex;

  const _StatStorySheet({
    required this.data,
    required this.initialIndex,
  });

  @override
  State<_StatStorySheet> createState() => _StatStorySheetState();
}

class _StatStorySheetState extends State<_StatStorySheet> {
  late final PageController _pageController;
  int _currentPage = 0;
  final _numTweets = 7;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_numTweets, (i) {
              return GestureDetector(
                onTap: () => _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == i ? 22 : 8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? AppTheme.neonPurple
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: List.generate(_numTweets, (i) => _TweetPage(
                index: i,
                data: widget.data,
              )),
            ),
          ),
        ],
      ),
    );
  }
}

class _TweetPage extends StatelessWidget {
  final int index;
  final _StatsData data;

  const _TweetPage({
    required this.index,
    required this.data,
  });

  static const _colors = [
    Color(0xFFFF6B35),
    AppTheme.neonPurple,
    Color(0xFF26C6DA),
    Color(0xFF26A69A),
    AppTheme.starGold,
    Color(0xFF66BB6A),
    Color(0xFF7E57C2),
  ];

  static const _labels = [
    'Day Streak',
    'All Entries',
    'Words',
    'Saved',
    'Stars',
    'Moods',
    'Quran Read',
  ];

  static const _handles = [
    '@streakmaster',
    '@journaler',
    '@wordweaver',
    '@curator',
    '@stargazer',
    '@moodwise',
    '@quranseek',
  ];

  static const _avatars = [
    '🔥',
    '📝',
    '✍️',
    '📖',
    '⭐',
    '🎭',
    '📖',
  ];

  String _valueText() {
    final quranPct = data.streakDays > 0 ? (data.quranDays * 100 ~/ data.streakDays) : 0;
    switch (index) {
      case 0: return '${data.streakDays} days';
      case 1: return '${data.totalEntries} entries';
      case 2: return '${_fmtWords(data.totalWords)} words';
      case 3: return '${data.savedFavorites} saved';
      case 4: return '${data.totalStars} stars';
      case 5: return '${data.moodCheckIns} moods';
      case 6: return '$quranPct% · ${data.quranDays} days';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final color = _colors[index];
    final body = _tweetFor(index, data);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          // ── Avatar row ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Text(_avatars[index], style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _labels[index],
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.starWhite,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _valueText(),
                            style: tt.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${_handles[index]} · 2m',
                      style: tt.labelSmall?.copyWith(
                        color: AppTheme.ghostSilver.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.more_horiz_rounded, color: AppTheme.ghostSilver.withValues(alpha: 0.5), size: 18),
            ],
          ),
          const SizedBox(height: 14),
          // ── Tweet body ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
            child: Text(
              body,
              style: tt.bodyLarge?.copyWith(
                color: AppTheme.starWhite,
                fontWeight: FontWeight.w400,
                fontSize: 16,
                height: 1.55,
              ),
            ),
          ),
          if (index == 1) ...[
            const SizedBox(height: 14),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _MonthlyBarChart(
                counts: data.monthlyEntries,
                barColor: _colors[1],
                currentMonth: DateTime.now().month - 1,
                barMaxHeight: 32,
                labelFontSize: 7,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // ── Engagement row ──
          Row(
            children: [
              _EngagementItem(icon: Icons.favorite_border_rounded, count: _likes(index, data), color: color),
              const SizedBox(width: 32),
              _EngagementItem(icon: Icons.repeat_rounded, count: _retweets(index, data), color: color),
              const SizedBox(width: 32),
              _EngagementItem(icon: Icons.chat_bubble_outline_rounded, count: _replies(index, data), color: color),
              const Spacer(),
              Icon(Icons.share_outlined, size: 18, color: AppTheme.ghostSilver.withValues(alpha: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  int _likes(int i, _StatsData d) {
    switch (i) {
      case 0: return d.streakDays * 3 + 5;
      case 1: return d.totalEntries * 2 + 3;
      case 2: return (d.totalWords ~/ 500) + 2;
      case 3: return d.savedFavorites * 4 + 2;
      case 4: return d.totalStars + 3;
      case 5: return d.moodCheckIns * 2 + 2;
      case 6: return d.quranDays * 3 + 5;
      default: return 0;
    }
  }

  int _retweets(int i, _StatsData d) {
    return (_likes(i, d) ~/ 3).clamp(1, 999);
  }

  int _replies(int i, _StatsData d) {
    return (_likes(i, d) ~/ 5).clamp(1, 999);
  }
}

class _EngagementItem extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _EngagementItem({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.ghostSilver.withValues(alpha: 0.5)),
        const SizedBox(width: 5),
        Text(
          count >= 1000 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
          style: TextStyle(
            color: AppTheme.ghostSilver.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
