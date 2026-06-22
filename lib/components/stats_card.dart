import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import '../services/journal_service.dart';
import '../services/streak_service.dart';
import '../services/favorites_service.dart';
import '../services/trial_service.dart';
import '../main.dart';
import '../theme/app_theme.dart';
import '../components/profilepage.dart';

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
  final List<int> weeklyActivity; // last 7 days entry counts
  final List<Map<String, String>> journals;

  const _StatsData({
    required this.totalEntries,
    required this.streakDays,
    required this.totalWords,
    required this.savedFavorites,
    required this.totalStars,
    required this.moodCheckIns,
    required this.quranDays,
    required this.monthlyEntries,
    required this.weeklyActivity,
    required this.journals,
  });
}

Future<_StatsData> _loadStats() async {
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
  final weekly = List<int>.filled(7, 0);
  int totalWords = 0;

  for (final j in journals) {
    final text = j['text'] ?? '';
    final dateStr = j['date'] ?? '';

    if (text.trim().isNotEmpty) {
      totalWords +=
          text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    }

    try {
      final d = DateTime.parse(dateStr);
      if (d.year == now.year) monthly[d.month - 1]++;
      // Weekly: check last 7 days
      final diff = now.difference(d).inDays;
      if (diff >= 0 && diff < 7) {
        weekly[6 - diff]++;
      }
    } catch (_) {}
  }

  final quranDays =
      prefs.getKeys().where((k) => k.startsWith('quran_revealed_')).length;

  return _StatsData(
    totalEntries: journals.length,
    streakDays: streak,
    totalWords: totalWords,
    savedFavorites: favorites.length,
    totalStars: prefs.getInt('total_stars') ?? 0,
    moodCheckIns: prefs.getInt('mood_checkin_count') ?? 0,
    quranDays: quranDays,
    monthlyEntries: monthly,
    weeklyActivity: weekly,
    journals: journals,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _fmtNum(int n) {
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
  const StatsCard({super.key, this.onTapEntries});

  final VoidCallback? onTapEntries;

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
  bool _isSubscribed = false;
  int _graceSeconds = 0;
  DateTime? _subscriptionExpiry;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _load();
    _checkSubscription();
    _loadGrace();
  }

  Future<void> _checkSubscription() async {
    try {
      final status = await Superwall.shared.getSubscriptionStatus();
      if (mounted) {
        setState(() {
          _isSubscribed = status.isActive;
        });
      }
    } catch (e) {
      debugPrint('[StatsCard] Subscription check error: $e');
    }
  }

  Future<void> _loadGrace() async {
    final ms = await TrialService.getRemainingMs();
    if (mounted) setState(() => _graceSeconds = (ms / 1000).ceil().clamp(0, 99999));
  }

  void _launchPaywall() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Superwall.shared.identify(user.uid);
      }
      Superwall.shared.registerPlacement('campaign_trigger', feature: () {
        debugPrint('[StatsCard] Feature callback fired — user is subscribed');
        if (mounted) _checkSubscription();
      });
    } catch (e) {
      debugPrint('[StatsCard] Paywall error: $e');
    }
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
              child: _bentoGrid(context, snap.data!),
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

  // ───────────────────────────────────────────────────────────────────────────
  // Bento grid layout
  // ───────────────────────────────────────────────────────────────────────────

  Widget _bentoGrid(BuildContext context, _StatsData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Row 1: C1: Streak + Breakdown + Analytics | C2: Entries + Subscription + Activity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _breakdownCard(data),
                    const SizedBox(height: 10),
                    _monthlyChartCard(data),
                    const SizedBox(height: 10),
                    _streakCard(data),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    _performanceCard(data),
                    const SizedBox(height: 10),
                    _subscriptionCard(),
                    const SizedBox(height: 10),
                    _weeklyBarCard(data),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Row 2: Quran gauge (full width)
          _quranGaugeCard(data),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. Streak card – yellow, like the QURAN gauge card
  // ───────────────────────────────────────────────────────────────────────────

  Widget _streakCard(_StatsData data) {
    const fg = Color(0xFFF1F1F1);

    return GestureDetector(
      onTap: () => Material3BottomNav.switchTab(context, 3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFF9D50FF).withValues(alpha: 0.2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'STREAK',
                      style: TextStyle(
                        color: fg,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Icon(Icons.arrow_upward_rounded,
                        color: fg, size: 24),
                    const SizedBox(width: 2),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          '${data.streakDays}',
                          style: const TextStyle(
                            color: fg,
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: Lottie.asset(
                        'assets/photos/elements/Streak Fire.json',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFFF6B35),
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Breakdown card – dark, like the DEVICE TYPE card
  // ───────────────────────────────────────────────────────────────────────────

  Widget _breakdownCard(_StatsData data) {
    const bg = Color(0xFF2A2A2A);
    const labelColor = Color(0xFFF1F1F1);
    const headerAccent = Color(0xFFF1F1F1);

    final items = <MapEntry<String, String>>[
      MapEntry('Entries', '${data.totalEntries}'),
      MapEntry('Words', _fmtNum(data.totalWords)),
      MapEntry('Favs', '${data.savedFavorites}'),
      MapEntry('Moods', '${data.moodCheckIns}'),
      MapEntry('Stars', '${data.totalStars}'),
    ];

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfilePage1()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'BREAKDOWN',
                  style: TextStyle(
                    color: headerAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                Icon(Icons.more_horiz_rounded,
                    color: Colors.white.withValues(alpha: 0.3), size: 16),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            color: labelColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        e.value,
                        style: const TextStyle(
                          color: labelColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Performance card – white, shows recent entry snippets
  // ───────────────────────────────────────────────────────────────────────────

  String _firstLine(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return lines.isEmpty ? '(empty)' : lines.first;
  }

  String _shortDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[d.month - 1]} ${d.day}';
    } catch (_) {
      return '';
    }
  }

  Widget _performanceCard(_StatsData data) {
    const fg = Color(0xFFF1F1F1);
    final entryBg = Colors.white.withValues(alpha: 0.08);
    const headerAccent = Color(0xFFF1F1F1);
    final total = data.totalEntries;
    final recent = data.journals.take(4).toList();

    return GestureDetector(
      onTap: widget.onTapEntries,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ENTRIES',
                      style: TextStyle(
                        color: headerAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '$total total',
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...recent.map((j) {
                  final text = j['text'] ?? '';
                  final dateStr = j['date'] ?? '';
                  final title = _firstLine(text);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: entryBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                color: fg,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _shortDate(dateStr),
                            style: TextStyle(
                              color: fg.withValues(alpha: 0.5),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. Monthly chart card – dark with yellow line
  // ───────────────────────────────────────────────────────────────────────────

  Widget _monthlyChartCard(_StatsData data) {
    const bg = Color(0xFF2A2A2A);
    const lineColor = Color(0xFFF5E6A3);
    final yearTotal = data.monthlyEntries.reduce((a, b) => a + b);

    return GestureDetector(
      onTap: () => _showStatDetail(context, data, 1),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'ANALYTICS',
                    style: TextStyle(
                      color: Color(0xFFF1F1F1),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                    '${_fmtNum(yearTotal)}+',
                    style: const TextStyle(
                      color: Color(0xFFF1F1F1),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: CustomPaint(
                painter: _LineChartPainter(
                  data: data.monthlyEntries,
                  lineColor: lineColor,
                  currentMonth: DateTime.now().month - 1,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('J-M',
                    style: TextStyle(
                        color: Color(0xFFF1F1F1),
                        fontSize: 8,
                        fontWeight: FontWeight.w500)),
                Text('A-J',
                    style: TextStyle(
                        color: Color(0xFFF1F1F1),
                        fontSize: 8,
                        fontWeight: FontWeight.w500)),
                Text('J-S',
                    style: TextStyle(
                        color: Color(0xFFF1F1F1),
                        fontSize: 8,
                        fontWeight: FontWeight.w500)),
                Text('O-D',
                    style: TextStyle(
                        color: Color(0xFFF1F1F1),
                        fontSize: 8,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 5. Weekly bar card – orange, horizontal bars like the reference
  // ───────────────────────────────────────────────────────────────────────────

  Widget _weeklyBarCard(_StatsData data) {
    const bg = Color(0xFFE8722A);
    const dotInactive = Color(0xFFB85A1E);

    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final totalDays = lastDay.day;
    final startWeekday = firstDay.weekday;

    final entryDays = <int>{};
    for (final j in data.journals) {
      try {
        final d = DateTime.parse(j['date'] ?? '');
        if (d.year == now.year && d.month == now.month) entryDays.add(d.day);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => _showStatDetail(context, data, 5),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MOOD',
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  now.month.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Calendar grid ──
            ...List.generate(_calendarRows(startWeekday, totalDays), (row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: List.generate(7, (col) {
                    final day = row * 7 + col - startWeekday + 2;
                    final isVisible = day >= 1 && day <= totalDays;
                    final hasEntry = isVisible && entryDays.contains(day);
                    final cellColor = hasEntry
                        ? const Color(0xFF3D2010)
                        : dotInactive.withValues(alpha: 0.35);
                    return Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          margin: const EdgeInsets.all(1.5),
                          decoration: BoxDecoration(
                            color: cellColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: isVisible
                              ? Text(
                                  '$day',
                                  style: TextStyle(
                                    color: hasEntry
                                        ? const Color(0xFFF1F1F1)
                                        : const Color(0xFF1A1A1A).withValues(alpha: 0.4),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  int _calendarRows(int startWeekday, int totalDays) {
    final cells = startWeekday - 1 + totalDays;
    return (cells / 7).ceil();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 6. Quran gauge card – yellow, semi-circle gauge
  // ───────────────────────────────────────────────────────────────────────────

  Widget _quranGaugeCard(_StatsData data) {
    const bg = Color(0xFFF5E6A3);
    const fg = Color(0xFF1A1A1A);

    final quranPct =
        data.streakDays > 0 ? (data.quranDays * 100 / data.streakDays) : 0.0;
    final pctDisplay = quranPct.round();
    final activeDays = data.quranDays;
    final totalDays = data.streakDays > 0 ? data.streakDays : 1;

    return GestureDetector(
      onTap: () => _showStatDetail(context, data, 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QURAN',
                      style: TextStyle(
                        color: fg,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: fg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Active · $activeDays days',
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: fg.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Total · $totalDays days',
                          style: TextStyle(
                            color: fg.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'This Month',
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: fg.withValues(alpha: 0.5), size: 14),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: Center(
                child: SizedBox(
                  width: 200,
                  height: 120,
                  child: CustomPaint(
                    painter: _GaugePainter(
                      percentage: quranPct / 100,
                      fg: fg,
                    ),
                    child: Align(
                      alignment: const Alignment(0, 0.5),
                      child: Text(
                        '$pctDisplay%',
                        style: const TextStyle(
                          color: fg,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 7. Subscription card
  // ───────────────────────────────────────────────────────────────────────────

  Widget _subscriptionCard() {
    const bg = Color(0xFFA5D6A7);
    const fg = Color(0xFF1A1A1A);
    final graceMin = (_graceSeconds / 60).floor();
    final inGrace = _graceSeconds > 0 && !_isSubscribed;
    final statusText = _isSubscribed ? 'Monthly' : (inGrace ? 'Trial' : 'Free');
    final subText = _isSubscribed ? 'Renews Jul 23' : (inGrace ? '$graceMin min left' : 'Tap to Unlock');
    final showBolt = !_isSubscribed;

    return GestureDetector(
      onTap: () {
        if (!_isSubscribed) {
          _launchPaywall();
        }
      },
      child: Container(
        height: 72,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'SUBSCRIPTION',
                  style: TextStyle(
                    color: fg,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: fg,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              children: [
                if (showBolt) ...[
                  Icon(Icons.bolt_rounded, size: 12, color: fg),
                  const SizedBox(width: 2),
                ],
                Text(
                  subText,
                  style: const TextStyle(
                    color: fg,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Stat detail bottom sheet (preserved from original)
  // ───────────────────────────────────────────────────────────────────────────

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
// Custom painters
// ─────────────────────────────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  final List<int> data;
  final Color lineColor;
  final int currentMonth;

  _LineChartPainter({
    required this.data,
    required this.lineColor,
    required this.currentMonth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final count = min(currentMonth + 1, data.length);
    if (count < 2) return;

    final maxVal = data.sublist(0, count).reduce(max).clamp(1, 9999999);
    final totalMonths = data.length;
    final points = <Offset>[];

    for (int i = 0; i < count; i++) {
      final x = i / (totalMonths - 1) * size.width;
      final y = size.height - (data[i] / maxVal * size.height * 0.85) - 4;
      points.add(Offset(x, y));
    }

    // Linear regression on existing data
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < count; i++) {
      sumX += i;
      sumY += data[i];
      sumXY += i * data[i];
      sumX2 += i * i;
    }
    final slope = (count * sumXY - sumX * sumY) / (count * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / count;

    final barPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final barW = size.width / totalMonths * 0.4;

    // Draw bars for existing data
    for (int i = 0; i < count; i++) {
      final x = i / (totalMonths - 1) * size.width;
      final barH = (data[i] / maxVal * size.height * 0.85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, size.height - barH / 2 - 4),
            width: barW,
            height: barH,
          ),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }

    // Draw fill
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Draw smooth line for existing data
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (points.length >= 2) {
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final cpx = (prev.dx + curr.dx) / 2;
        linePath.cubicTo(cpx, prev.dy, cpx, curr.dy, curr.dx, curr.dy);
      }
      canvas.drawPath(linePath, linePaint);
    }

    // ── Estimated trajectory ──────────────────────────────────────────
    if (count < totalMonths) {
      final projectedPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.45)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final projPoints = <Offset>[];
      for (int i = count; i < totalMonths; i++) {
        final projVal = (slope * i + intercept).clamp(0, maxVal * 1.5).toInt();
        final x = i / (totalMonths - 1) * size.width;
        final y = size.height - (projVal / maxVal * size.height * 0.85) - 4;
        projPoints.add(Offset(x, y));

        // Bars for projected months
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x, size.height - (projVal / maxVal * size.height * 0.85) / 2 - 4),
              width: barW,
              height: projVal / maxVal * size.height * 0.85,
            ),
            const Radius.circular(2),
          ),
          barPaint,
        );
      }

      if (projPoints.isNotEmpty) {
        final allPoints = [...points, ...projPoints];
        final projPath = Path()
          ..moveTo(allPoints.first.dx, allPoints.first.dy);
        for (int i = 1; i < allPoints.length; i++) {
          final prev = allPoints[i - 1];
          final curr = allPoints[i];
          final cpx = (prev.dx + curr.dx) / 2;
          projPath.cubicTo(cpx, prev.dy, cpx, curr.dy, curr.dx, curr.dy);
        }
        canvas.drawPath(projPath, projectedPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _GaugePainter extends CustomPainter {
  final double percentage; // 0.0 – 1.0
  final Color fg;

  _GaugePainter({required this.percentage, required this.fg});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 8);
    final radius = min(size.width / 2, size.height) - 12;
    const startAngle = pi; // 180°
    const sweepTotal = pi;  // 180° sweep
    const tickCount = 40;

    // Background ticks
    for (int i = 0; i < tickCount; i++) {
      final angle = startAngle + (i / tickCount) * sweepTotal;
      final isFilled = i / tickCount <= percentage;
      final paint = Paint()
        ..color = isFilled ? fg : fg.withValues(alpha: 0.15)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      final innerR = radius - 18;
      final outerR = radius;
      final p1 = Offset(
          center.dx + innerR * cos(angle), center.dy + innerR * sin(angle));
      final p2 = Offset(
          center.dx + outerR * cos(angle), center.dy + outerR * sin(angle));
      canvas.drawLine(p1, p2, paint);
    }

    // Small marker at the end of the gauge
    final markerAngle = startAngle + percentage.clamp(0.0, 1.0) * sweepTotal;
    final markerR = radius + 6;
    final markerPos = Offset(center.dx + markerR * cos(markerAngle),
        center.dy + markerR * sin(markerAngle));
    canvas.drawCircle(
        markerPos,
        3,
        Paint()
          ..color = fg.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// Tweet-style Stat Story Carousel (preserved)
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
      if (w >= 10000) return "You've written ${_fmtNum(w)} words! That's a short novel's worth of reflections. Your voice has volume and depth. 📚✨";
      if (w >= 1000) return "You've written ${_fmtNum(w)} words! That's essay territory. Your thoughts have range and your voice is finding its rhythm. 📚";
      return "You've written ${_fmtNum(w)} words. Every word you write is a step forward in your journey. ✍️";
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
      height: screenHeight * 0.30,
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
      case 2: return '${_fmtNum(data.totalWords)} words';
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
          borderRadius: BorderRadius.circular(100),
                ),
                alignment: Alignment.center,
                child: ClipOval(
                  child: Image.asset(
                    'assets/photos/mascot/hi.webp',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text(_avatars[index], style: const TextStyle(fontSize: 20)),
                  ),
                ),
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
              child: _MonthlyBarChartSmall(
                counts: data.monthlyEntries,
                barColor: _colors[1],
                currentMonth: DateTime.now().month - 1,
              ),
            ),
          ],
          const SizedBox(height: 16),
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

// Small bar chart used inside the tweet detail sheet
class _MonthlyBarChartSmall extends StatelessWidget {
  final List<int> counts;
  final Color barColor;
  final int currentMonth;

  const _MonthlyBarChartSmall({
    required this.counts,
    required this.barColor,
    required this.currentMonth,
  });

  @override
  Widget build(BuildContext context) {
    final all = List<int>.generate(12, (i) {
      if (i <= currentMonth) return counts[i];
      return 0;
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
        final value = counts[i];
        final fraction = value / maxVal;
        final barH = (fraction * 32).clamp(2.0, 32.0);

        Color barColorResolved;
        if (isNow) {
          barColorResolved = barColor;
        } else if (isFuture) {
          barColorResolved = barColor.withValues(alpha: 0.15);
        } else {
          barColorResolved = barColor.withValues(alpha: value > 0 ? 0.55 : 0.12);
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
                  fontSize: 7,
                  fontWeight: isNow ? FontWeight.w800 : FontWeight.w400,
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
