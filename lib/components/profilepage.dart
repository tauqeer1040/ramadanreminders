import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/streak_service.dart';
import '../services/journal_service.dart';
import '../services/audio_service.dart';
import '../services/sfx_service.dart';
import '../screens/manage_account_screen.dart';
import '../theme/app_theme.dart';
import '../screens/onboarding_screen.dart';
import 'widgets/streak_graph.dart';
import 'widgets/duo_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage1 extends StatefulWidget {
  const ProfilePage1({super.key});

  @override
  State<ProfilePage1> createState() => _ProfilePage1State();
}

class _ProfilePage1State extends State<ProfilePage1> {
  User? _currentUser;
  bool _isLoading = false;
  bool _notificationsGranted = false;
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  int _streak = 0;
  int _totalJournals = 0;
  int _quranDays = 0;
  List<bool> _last7Days = List.filled(7, false);

  // Onboarding data
  String? _onboardingIntention;
  String? _onboardingHeart;
  String? _onboardingChallenge;
  String? _onboardingJourney;
  String? _onboardingCommitment;
  int? _onboardingAge;
  int? _onboardingPhoneHours;
  String? _onboardingCatName;

  @override
  void initState() {
    super.initState();
    _currentUser = AuthService.currentUser;
    _musicEnabled = BackgroundMusicService().isMusicEnabled;
    _sfxEnabled = SfxService().isSfxEnabled;
    _checkNotificationStatus();
    _loadStats();
    _loadOnboardingData();
    AuthService.authStateChanges.listen((user) {
      if (mounted) {
        setState(() => _currentUser = user);
        _loadStats();
      }
    });
  }

  Future<void> _loadStats() async {
    final streak = await StreakService.getStreak();
    final last7 = await StreakService.getLast7Days();
    final journals = await JournalService.getAllLocalJournals();
    final prefs = await SharedPreferences.getInstance();
    final quranDays = prefs.getKeys().where((k) => k.startsWith('quran_revealed_')).length;
    if (mounted) {
      setState(() {
        _streak = streak;
        _last7Days = last7;
        _totalJournals = journals.length;
        _quranDays = quranDays;
      });
    }
  }

  Future<void> _loadOnboardingData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _onboardingIntention = prefs.getString('onboarding_intention');
      _onboardingHeart = prefs.getString('onboarding_heart');
      _onboardingChallenge = prefs.getString('onboarding_challenge');
      _onboardingJourney = prefs.getString('onboarding_journey');
      _onboardingCommitment = prefs.getString('onboarding_commitment');
      _onboardingAge = prefs.getInt('onboarding_age');
      _onboardingPhoneHours = prefs.getInt('onboarding_phoneHours');
      _onboardingCatName = prefs.getString('onboarding_catName');
    });
  }

  Future<void> _checkNotificationStatus() async {
    final enabled = await NotificationService.checkPermissions();
    if (mounted) {
      setState(() => _notificationsGranted = enabled);
    }
  }

  Future<void> _toggleNotifications() async {
    if (_notificationsGranted) return;
    final granted = await NotificationService.requestPermissions();
    if (mounted) setState(() => _notificationsGranted = granted);
    if (granted && mounted) {
      NotificationService.scheduleDailyNotifications();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.star_rounded, color: AppTheme.starGold, size: 20),
              SizedBox(width: 8),
              Text('Notifications enabled! Barakallahu feekum 🌙'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String get _displayName {
    if (_currentUser == null || _currentUser!.isAnonymous) return 'Guest User';
    return _currentUser!.displayName ??
        _currentUser!.email?.split('@')[0] ??
        'Believer';
  }

  String get _archetype {
    if (_totalJournals >= 20) return 'The Devoted 🌟';
    if (_totalJournals >= 10) return 'The Reflective 📖';
    if (_totalJournals >= 5) return 'The Seeker 🌙';
    if (_totalJournals >= 1) return 'The Beginner 🌱';
    return 'The Newcomer ✨';
  }

  String get _streakLabel {
    if (_streak >= 30) return 'Masha\'Allah! 30+ Days 🔥';
    if (_streak >= 14) return 'Two Weeks Strong 💪';
    if (_streak >= 7) return 'One Week! Keep Going 🌟';
    if (_streak >= 3) return 'On a Roll 🎯';
    return 'Just Started 🌱';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: AppTheme.neonPurple,
        backgroundColor: const Color(0xFF1A1A2E),
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          children: [
            const SizedBox(height: 32),

            // ── Account & Sync ──────────────────────────────────────────────
            _buildAccountCard(),
            const SizedBox(height: 16),

            // ── Streak Graph ────────────────────────────────────────────────
            StreakGraph(streak: _streak, size: 220),
            const SizedBox(height: 16),

            // ── Spiritual Profile ───────────────────────────────────────────
            _buildSectionCard(
              title: 'SPIRITUAL PROFILE',
              icon: Icons.auto_awesome_rounded,
              iconColor: AppTheme.neonPurple,
              child: _buildSpiritualProfile(),
            ),
            const SizedBox(height: 16),

            // ── Activity Stats ──────────────────────────────────────────────
            _buildSectionCard(
              title: 'YOUR STATS',
              icon: Icons.bar_chart_rounded,
              iconColor: const Color(0xFF58CC02),
              child: _buildStatsRow(),
            ),
            const SizedBox(height: 16),

            // ── Last 7 Days Activity ────────────────────────────────────────
            _buildSectionCard(
              title: 'LAST 7 DAYS',
              icon: Icons.calendar_today_rounded,
              iconColor: const Color(0xFF0052FF),
              child: _buildLast7Days(),
            ),
            const SizedBox(height: 16),

            // ── Notifications ───────────────────────────────────────────────
            if (!_notificationsGranted) ...[
              _buildNotificationCard(),
              const SizedBox(height: 16),
            ],

            // ── Audio Settings ────────────────────────────────────────────
            _buildAudioCard(),
            const SizedBox(height: 16),

            // ── Account & Sync ──────────────────────────────────────────────
            _buildAccountCard(),
            const SizedBox(height: 16),

            // ── Replay Onboarding ───────────────────────────────────────────
            _replayOnboardingCard(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── CARDS ──────────────────────────────────────────────────────────────────

  Widget _buildUserCard() {
    final isAnonymous = _currentUser?.isAnonymous ?? true;
    final initials = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'B';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(borderColor: AppTheme.neonPurple.withValues(alpha: 0.3)),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.neonPurple.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.neonPurple, width: 2),
            ),
            child: _currentUser?.photoURL != null && _currentUser!.photoURL!.isNotEmpty
                ? ClipOval(child: Image.network(_currentUser!.photoURL!, fit: BoxFit.cover))
                : Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.neonPurple,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.starWhite,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAnonymous ? 'Guest — Sign in to save progress' : (_currentUser?.email ?? ''),
                  style: const TextStyle(fontSize: 13, color: AppTheme.ghostSilver),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.neonPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _archetype,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.neonPurple,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpiritualProfile() {
    final quranPct = _streak > 0 ? ((_quranDays / _streak) * 100).round() : 0;
    return Column(
      children: [
        _buildProfileRow('Display Name', _displayName),
        _buildProfileRow('Spiritual Archetype', _archetype),
        _buildProfileRow('Journals Written', '$_totalJournals ${_totalJournals == 1 ? "entry" : "entries"} 📓'),
        _buildProfileRow('Quran Read', '$_quranDays days — $quranPct% 📖'),
        _buildProfileRow('Account Status', _currentUser?.isAnonymous == false ? 'Synced ✅' : 'Guest Mode 👤'),
        if (_onboardingAge != null) _buildProfileRow('Age', '${_onboardingAge}'),
        if (_onboardingPhoneHours != null) _buildProfileRow('Avg. Phone Time', '~${_onboardingPhoneHours}h/day 📱'),
        if (_onboardingCatName != null && _onboardingCatName!.isNotEmpty) _buildProfileRow('Cat Name', _onboardingCatName!),
        if (_onboardingIntention != null) _buildProfileRow('Intention', _onboardingIntention!),
        if (_onboardingHeart != null) _buildProfileRow('Heart State', _onboardingHeart!),
        if (_onboardingChallenge != null) _buildProfileRow('Biggest Barrier', _onboardingChallenge!),
        if (_onboardingJourney != null) _buildProfileRow('Journey', _onboardingJourney!),
        if (_onboardingCommitment != null) _buildProfileRow('Commitment', _onboardingCommitment!),
        const Divider(color: AppTheme.ghostSilver, height: 24),
        _buildProfileRow('Current Streak', '$_streak ${_streak == 1 ? "day" : "days"} 🔥'),
        _buildProfileRow('Streak Status', _streakLabel),
      ],
    );
  }

  Widget _buildStatsRow() {
    final activeDays = _last7Days.where((d) => d).length;
    final consistencyPct = ((activeDays / 7) * 100).round();

    return Row(
      children: [
        _buildStatItem(
          icon: Icons.book_rounded,
          iconColor: AppTheme.neonPurple,
          label: 'Journals',
          value: '$_totalJournals',
        ),
        _buildStatItem(
          icon: Icons.local_fire_department_rounded,
          iconColor: AppTheme.starGold,
          label: 'Streak',
          value: '${_streak}d',
        ),
        _buildStatItem(
          icon: Icons.gps_fixed_rounded,
          iconColor: const Color(0xFF58CC02),
          label: 'Consistency',
          value: '$consistencyPct%',
        ),
      ],
    );
  }

  Widget _buildLast7Days() {
    const dayLetters = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final now = DateTime.now();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (i) {
        final day = now.subtract(Duration(days: 6 - i));
        final isToday = i == 6;
        final isActive = _last7Days[i];
        final dayLetter = dayLetters[day.weekday - 1];

        return Column(
          children: [
            Text(
              dayLetter,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isToday ? AppTheme.starWhite : AppTheme.ghostSilver,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? AppTheme.starGold.withValues(alpha: 0.2)
                    : AppTheme.starWhite.withValues(alpha: 0.06),
                border: Border.all(
                  color: isActive
                      ? AppTheme.starGold
                      : (isToday
                          ? AppTheme.neonPurple.withValues(alpha: 0.5)
                          : AppTheme.starWhite.withValues(alpha: 0.1)),
                  width: isActive || isToday ? 2 : 1,
                ),
              ),
              child: isActive
                  ? const Icon(Icons.check_rounded, color: AppTheme.starGold, size: 18)
                  : isToday
                      ? const Icon(Icons.circle, color: AppTheme.neonPurple, size: 10)
                      : null,
            ),
          ],
        );
      }),
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(borderColor: AppTheme.starGold.withValues(alpha: 0.3)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.starGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_active_rounded, color: AppTheme.starGold, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Reminders',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.starWhite),
                ),
                SizedBox(height: 3),
                Text(
                  'Get daily prayer & reflection reminders 🌙',
                  style: TextStyle(fontSize: 12, color: AppTheme.ghostSilver),
                ),
              ],
            ),
          ),
          Switch(
            value: false,
            onChanged: (_) => _toggleNotifications(),
            activeThumbColor: AppTheme.starGold,
            activeTrackColor: AppTheme.starGold.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(borderColor: AppTheme.neonPurple.withValues(alpha: 0.3)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.neonPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.music_note_rounded, color: AppTheme.neonPurple, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'AUDIO',
                  style: TextStyle(
                    color: AppTheme.starWhite,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildToggleRow(
            icon: Icons.music_note_rounded,
            label: 'Background Music',
            subtitle: 'BGM plays throughout the app',
            value: _musicEnabled,
            onChanged: (val) async {
              await BackgroundMusicService().setMusicEnabled(val);
              setState(() => _musicEnabled = val);
            },
          ),
          Divider(color: AppTheme.starWhite.withValues(alpha: 0.08), height: 24),
          _buildToggleRow(
            icon: Icons.volume_up_rounded,
            label: 'Sound Effects',
            subtitle: 'Button tap sounds and tones',
            value: _sfxEnabled,
            onChanged: (val) async {
              await SfxService().setSfxEnabled(val);
              setState(() => _sfxEnabled = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.ghostSilver),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.starWhite),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppTheme.ghostSilver),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.neonPurple,
          activeTrackColor: AppTheme.neonPurple.withValues(alpha: 0.3),
        ),
      ],
    );
  }

  Widget _buildAccountCard() {
    final isAnonymous = _currentUser == null || _currentUser!.isAnonymous;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration().copyWith(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAnonymous) ...[
            const Text(
              'Sign in with Google to sync your journals, streaks, and reflections across all your devices.',
              style: TextStyle(color: AppTheme.ghostSilver, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: AppTheme.neonPurple))
            else
              DuoButton(
                onPressed: () async {
                  setState(() => _isLoading = true);
                  await AuthService.signInWithGoogle();
                  if (mounted) setState(() => _isLoading = false);
                },
                backgroundColor: Colors.white,
                depthColor: Colors.grey[400]!,
                height: 52,
                radius: 14,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.g_mobiledata, size: 28, color: Colors.black),
                    SizedBox(width: 10),
                    Text(
                      'Continue with Google',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ManageAccountScreen(user: _currentUser!),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.neonPurple, width: 2),
                      ),
                      child: _currentUser?.photoURL != null
                          ? ClipOval(child: Image.network(_currentUser!.photoURL!, fit: BoxFit.cover))
                          : Icon(Icons.person, size: 24, color: AppTheme.neonPurple),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUser?.displayName ?? 'User',
                            style: const TextStyle(
                              color: AppTheme.starWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _currentUser?.email ?? '',
                            style: const TextStyle(
                              color: AppTheme.ghostSilver,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.ghostSilver),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── REPLAY ONBOARDING ──────────────────────────────────────────────────────

  Widget _replayOnboardingCard() {
    return DuoButton(
      onPressed: _replayOnboarding,
      backgroundColor: AppTheme.neonPurple.withValues(alpha: 0.15),
      depthColor: AppTheme.neonPurple.withValues(alpha: 0.08),
      radius: 16,
      height: 56,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.replay, color: AppTheme.neonPurple, size: 20),
          SizedBox(width: 10),
          Text(
            'Replay Onboarding',
            style: TextStyle(
              color: AppTheme.neonPurple,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _replayOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', false);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.starWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.ghostSilver,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppTheme.starWhite,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.starWhite,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.ghostSilver,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration({Color? borderColor}) => BoxDecoration(
    color: const Color(0xFF1A1A2E),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: borderColor ?? const Color(0xFF2A2A4A),
      width: 1.5,
    ),
    boxShadow: const [
      BoxShadow(
        color: Color(0x33000000),
        offset: Offset(0, 4),
        blurRadius: 0,
      ),
    ],
  );
}
