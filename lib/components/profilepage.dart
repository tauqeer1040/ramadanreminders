import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/streak_service.dart';
import '../services/journal_service.dart';
import '../services/audio_service.dart';
import '../services/sfx_service.dart';
import '../screens/manage_account_screen.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../screens/onboarding_screen.dart';
import 'widgets/streak_graph.dart';
import 'widgets/duo_button.dart';
import 'action_prompt_card.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';

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
    AuthService.userChanges.listen((user) {
      if (mounted) {
        setState(() => _currentUser = user);
        _loadStats();
      }
    });
  }

  Future<void> _loadStats() async {
    final streak = await StreakService.getStreak();
    final journals = await JournalService.getAllLocalJournals();
    final prefs = await SharedPreferences.getInstance();
    final quranDays = prefs.getKeys().where((k) => k.startsWith('quran_revealed_')).length;
    if (mounted) {
      setState(() {
        _streak = streak;
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
      await _incrementStars(100);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.star_rounded, color: AppTheme.starGold, size: 20),
                SizedBox(width: 8),
                Text('Notifications enabled! +100 ⭐'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _incrementStars(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('total_stars') ?? 0;
    await prefs.setInt('total_stars', current + amount);
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

            // ── Mood Calendar ────────────────────────────────────────────────
            _buildSectionCard(
              title: 'MOOD CALENDAR',
              icon: Icons.grid_view_rounded,
              iconColor: const Color(0xFF58CC02),
              child: _buildMoodCalendar(),
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

            // ── Homescreen Widget ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
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
                    if (mounted) {
                      await _incrementStars(100);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.star_rounded, color: AppTheme.starGold, size: 20),
                              SizedBox(width: 8),
                              Text('Widget added! +100 ⭐'),
                            ],
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
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
            const SizedBox(height: 16),

            // ── Notification Prompt ────────────────────────────────────────
            if (!_notificationsGranted)
              ActionPromptCard(
                title: 'Set the reminder',
                subtitle:
                    'Never miss your morning routine!\nSet a reminder to stay on track',
                buttonText: 'Set Now',
                onPressed: _toggleNotifications,
                backgroundColor: const Color(0xFFFFE0B2),
                foregroundColor: const Color(0xFF4E342E),
                icon: const Icon(
                  Icons.notifications_active_rounded,
                  size: 64,
                  color: Color(0xFFFF7043),
                ),
              ),
            const SizedBox(height: 16),

            // ── Share ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0),
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
            const SizedBox(height: 16),

            // ── Replay Onboarding ───────────────────────────────────────────
            _replayOnboardingCard(),
            const SizedBox(height: 12),
            _subscribeCard(),
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

  Widget _buildMoodCalendar() {
    return _MoodCalendarGrid();
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
                      child: (() {
                        final photoUrl = AuthService.getPhotoUrl(_currentUser);
                        if (photoUrl != null && photoUrl.isNotEmpty) {
                          return ClipOval(
                            child: Image.network(photoUrl, fit: BoxFit.cover),
                          );
                        }
                        return Icon(Icons.person, size: 24, color: AppTheme.neonPurple);
                      }()),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _currentUser?.displayName ?? 'User',
                                  style: const TextStyle(
                                    color: AppTheme.starWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: _showEditNameDialog,
                                child: Icon(
                                  Icons.edit_rounded,
                                  size: 14,
                                  color: AppTheme.neonPurple.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
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

  void _showEditNameDialog() {
    final controller = TextEditingController(text: _currentUser?.displayName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Name', style: TextStyle(color: AppTheme.starWhite, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          maxLengthEnforcement: MaxLengthEnforcement.truncateAfterCompositionEnds,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: AppTheme.starWhite, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(color: AppTheme.ghostSilver.withValues(alpha: 0.5)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            counter: const SizedBox.shrink(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.ghostSilver)),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _updateDisplayName(name);
            },
            child: const Text('Save', style: TextStyle(color: AppTheme.neonPurple, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDisplayName(String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.updateDisplayName(name);
      await user.reload();
      await UserService.syncUser(FirebaseAuth.instance.currentUser!);
      if (mounted) setState(() {});
    } catch (_) {}
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

  Widget _subscribeCard() {
    return DuoButton(
      onPressed: _showPaywall,
      backgroundColor: AppTheme.starGold,
      depthColor: AppTheme.starGold.withValues(alpha: 0.6),
      radius: 16,
      height: 56,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.workspace_premium, color: Colors.black, size: 20),
          SizedBox(width: 10),
          Text(
            'Subscribe',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaywall() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Launching paywall...'),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('[ProfilePaywall] User: ${user?.uid} anonymous: ${user?.isAnonymous}');
      if (user != null) {
        Superwall.shared.identify(user.uid);
      }
      Superwall.shared.registerPlacement('campaign_trigger', feature: () {
        debugPrint('[ProfilePaywall] Feature callback fired');
      });
    } catch (e) {
      debugPrint('[ProfilePaywall] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
    ),
  );

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

// ─────────────────────────────────────────────────────────────────────────────
// Mood Calendar Grid
// ─────────────────────────────────────────────────────────────────────────────

class _MoodCalendarGrid extends StatefulWidget {
  @override
  State<_MoodCalendarGrid> createState() => _MoodCalendarGridState();
}

class _MoodCalendarGridState extends State<_MoodCalendarGrid> {
  late DateTime _currentMonth;
  Map<String, double> _moodData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadMoods();
  }

  Future<void> _loadMoods() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, double>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith('mood_')) {
        final dateStr = key.substring(5);
        final val = double.tryParse(prefs.getString(key) ?? '');
        if (val != null) data[dateStr] = val;
      }
    }
    if (mounted) setState(() {
      _moodData = data;
      _loading = false;
    });
  }

  void _prevMonth() => setState(() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
  });

  void _nextMonth() => setState(() {
    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
  });

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final isFuture = _currentMonth.isAfter(thisMonth);

    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final monthLabel = DateFormat('MMMM yyyy').format(_currentMonth);

    return Column(
      children: [
        // ── Month navigation ──────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              color: Colors.white.withValues(alpha: 0.60),
              onPressed: _prevMonth,
            ),
            Text(
              monthLabel,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              color: isFuture
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.60),
              onPressed: isFuture ? null : _nextMonth,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Day labels ─────────────────────────────────────────
        Row(
          children: dayLabels.map((l) => Expanded(
            child: Center(
              child: Text(
                l,
                style: tt.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.40),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 6),

        // ── Day cells ──────────────────────────────────────────
        ...List.generate(_weeksCount(daysInMonth, firstWeekday), (week) {
          return Row(
            children: List.generate(7, (weekday) {
              final day = week * 7 + weekday - firstWeekday + 1;
              final isValid = day >= 1 && day <= daysInMonth;
              final dateStr = isValid
                  ? '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}'
                  : '';

              final moodVal = isValid ? _moodData[dateStr] : null;
              final isToday = isValid && dateStr == now.toIso8601String().substring(0, 10);

              return Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    margin: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: moodVal != null
                          ? _moodColor(moodVal).withValues(alpha: 0.55)
                          : (isToday
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.transparent),
                      borderRadius: BorderRadius.circular(6),
                      border: isToday && moodVal == null
                          ? Border.all(color: AppTheme.neonPurple.withValues(alpha: 0.30), width: 1)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        isValid ? '$day' : '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: moodVal != null ? FontWeight.w700 : FontWeight.w400,
                          color: moodVal != null
                              ? Colors.white
                              : (isToday
                                  ? AppTheme.neonPurple.withValues(alpha: 0.60)
                                  : Colors.white.withValues(alpha: 0.25)),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        }),
        const SizedBox(height: 8),

        // ── Legend ──────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(const Color(0xFF5C6BC0)),
            const SizedBox(width: 4),
            Text('Low', style: tt.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.40))),
            const SizedBox(width: 12),
            _legendDot(const Color(0xFFAB47BC)),
            const SizedBox(width: 4),
            Text('Med', style: tt.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.40))),
            const SizedBox(width: 12),
            _legendDot(const Color(0xFF7CB342)),
            const SizedBox(width: 4),
            Text('High', style: tt.labelSmall?.copyWith(color: Colors.white.withValues(alpha: 0.40))),
          ],
        ),
      ],
    );
  }

  Widget _legendDot(Color c) => Container(
    width: 10, height: 10,
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(3),
    ),
  );

  int _weeksCount(int days, int firstWeekday) =>
      ((days + firstWeekday + 6) ~/ 7).clamp(4, 6);

  Color _moodColor(double val) {
    if (val < 0.35) return const Color(0xFF5C6BC0);
    if (val < 0.65) return const Color(0xFFAB47BC);
    return const Color(0xFF7CB342);
  }
}
