import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'widgets/deferred_lottie.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../services/sfx_service.dart';
import '../services/trial_service.dart';
import '../services/widget_service.dart';
import '../services/pwa_install_service.dart';
import '../services/journal_remote_storage.dart';
import 'widgets/pwa_install_dialog.dart';
import '../services/journal_service.dart';
import '../core/constants.dart';
import '../screens/manage_account_screen.dart';
import '../services/user_service.dart';
import '../services/streak_service.dart';
import '../services/invite_service.dart';
import 'widgets/complete_registration_sheet.dart';
import '../theme/app_theme.dart';
import 'stats_card.dart';
import 'widgets/duo_button.dart';
import 'widgets/auth_debug_card.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart' deferred as hw;
import 'package:share_plus/share_plus.dart' deferred as share_plus;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/about_screen.dart';
import '../services/insight_service.dart';

class ProfilePage1 extends StatefulWidget {
  const ProfilePage1({super.key});

  @override
  State<ProfilePage1> createState() => _ProfilePage1State();
}

class _ProfilePage1State extends State<ProfilePage1>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  User? _currentUser;
  bool _isLoading = false;
  bool _notificationsGranted = false;
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  String _debugTrial = '';
  String _debugAuth = '';
  String _debugShopCache = '';
  String _debugLastError = '';
  String _serverStatus = 'yellow';
  String _dbStatus = 'yellow';
  bool _debugExpanded = false;

  final List<Uint8List?> _covers = [null];
  bool _loadingCovers = true;

  late AnimationController _wobbleCtrl;
  late CurvedAnimation _wobbleAnim;
  Timer? _wobbleTimer;
  Timer? _healthTimer;
  String _lastSync = '';
  List<InsightCard> _insightCards = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUser = AuthService.currentUser;
    _musicEnabled = BackgroundMusicService().isMusicEnabled;
    _sfxEnabled = SfxService().isSfxEnabled;
    _checkNotificationStatus();
    _loadStats();
    AuthService.userChanges.listen((user) {
      if (mounted) {
        setState(() => _currentUser = user);
        _loadStats();
      }
    });

    // Single track: always study session
    _loadCovers();

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
    _startHealthPolling();
    _loadInsights();
  }

  Future<void> _loadCovers() async {
    try {
      final bd = await rootBundle.load('assets/photos/elements/cover_am_session.webp');
      _covers[0] = bd.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error loading covers in profile: $e");
    }
    if (mounted) {
      setState(() => _loadingCovers = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wobbleCtrl.dispose();
    _wobbleTimer?.cancel();
    _healthTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    String debugTrial = '';
    String debugAuth = '';
    String debugShopCache = '';
    String lastSync = '';
    String lastError = '';

    try {
      final prefs = await SharedPreferences.getInstance();
      lastSync = _fmtLastSync(prefs.getString('last_sync_at'));
      final shopCache = prefs.getString('shop_items_cache');
      debugShopCache = shopCache != null
          ? '${(shopCache.length / 1024).toStringAsFixed(1)} KB'
          : '—';
    } catch (e) {
      lastError = 'prefs: $e';
      debugPrint('[Profile] prefs failed: $e');
    }

    try {
      final user = AuthService.currentUser;
      final isAnon = user?.isAnonymous ?? true;
      debugAuth = '${user?.uid ?? "—"} (${isAnon ? "anonymous" : "signed-in"})';
    } catch (e) {
      lastError = 'auth: $e';
      debugPrint('[Profile] auth failed: $e');
    }

    try {
      final trialStatus = await TrialService.getStatus();
      final trialRemainingMs = await TrialService.getRemainingMs();
      debugTrial = trialStatus.trialActive
          ? _fmtTrial(trialRemainingMs)
          : 'expired';
    } catch (e) {
      lastError = 'trial: $e';
      debugPrint('[Profile] trial failed: $e');
    }

    if (mounted) {
      setState(() {
        _debugAuth = debugAuth;
        _debugTrial = debugTrial;
        _debugShopCache = debugShopCache;
        _lastSync = lastSync;
        _debugLastError = lastError;
      });
    }

    _performHealthCheck();
  }

  Future<void> _onRefresh() async {
    await JournalRemoteStorage.pullAllJournalsToLocal();
    JournalService.notifyJournalsChanged();
    StatsCard.refresh(context);
    _loadCovers();
    await _loadStats();
  }

  Future<void> _loadInsights() async {
    if (!mounted) return;
    final cards = await InsightService.fetchPersonalizedInsights(limit: 3);
    if (mounted) setState(() => _insightCards = cards);
  }

  void _startHealthPolling() {
    _healthTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _performHealthCheck();
    });
  }

  Future<void> _performHealthCheck() async {
    try {
      final checkUrl = '${AppConstants.backendUrl}/app-version';
      final res = await http
          .get(Uri.parse(checkUrl))
          .timeout(const Duration(seconds: 5));
      final ok = res.statusCode == 200;
      if (mounted) {
        setState(() {
          _serverStatus = ok ? 'green' : 'red';
          _dbStatus = ok ? 'green' : 'red';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _serverStatus = 'red';
          _dbStatus = 'red';
        });
      }
    }
  }

  String _fmtLastSync(String? iso) {
    if (iso == null || iso.isEmpty) return 'never';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
      if (!kIsWeb) NotificationService.scheduleDailyNotifications();
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
    await _loadStats();
  }

  void _openWhatsApp() async {
    await _incrementStars(100);
    const url = 'https://chat.whatsapp.com/FDyQLduHssu4Ylh3t1sqTB?s=sh&p=a&ilr=0';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp. Please install WhatsApp first.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppTheme.neonPurple,
        backgroundColor: const Color(0xFF1A1A2E),
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
          children: [
            // ── Top Bar: Avatar · Logo · Favorites ──────────────────────────
            SizedBox(
              height: 128,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AboutScreen(),
                              ),
                            );
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
                InkWell(
                  onTap: _openRegistration,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.starGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: AppTheme.starGold,
                      size: 28,
                    ),
                  ),
                ),
                  ],
                ),
              ),
            ),

            // ── Account & Sync ──────────────────────────────────────────────
            _buildAccountCard(),
            const SizedBox(height: 16),

            // ── Stats Card ────────────────────────────────────────────────
            StatsCard(),
            const SizedBox(height: 24),



            // ── Notifications ───────────────────────────────────────────────
            if (!_notificationsGranted) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Users who enable reminders are 2x more consistent 🌙',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.starWhite.withValues(alpha: 0.5),
                  ),
                ),
              ),
              _buildNotificationCard(),
              const SizedBox(height: 24),
            ],

            // ── Audio Settings ────────────────────────────────────────────
            _buildAudioCard(),
            const SizedBox(height: 24),

            DuoButton(
                onPressed: _pickWidget,
                backgroundColor: const Color(0xFFAB47BC),
                depthColor: const Color(0xFF7B1FA2),
                radius: 16,
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(kIsWeb ? Icons.add_to_home_screen_rounded : Icons.widgets_rounded, size: 20, color: AppTheme.starWhite),
                    const SizedBox(width: 10),
                    Text(
                      kIsWeb ? 'Install App on Home Screen +100 ⭐' : 'Add Homescreen Widget +100 ⭐',
                      style: const TextStyle(
                        color: AppTheme.starWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ── Share ──────────────────────────────────────────────────────
            DuoButton(
              onPressed: () async {
                await share_plus.loadLibrary();
                final url = await InviteService.buildInviteUrl() ??
                    (kIsWeb
                        ? 'https://meowmin.taucity.xyz'
                        : 'https://play.google.com/store/apps/details?id=com.taucity.meowmin');
                share_plus.Share.share(
                  '🌙 Join me on Meowmin and we\'ll shield each other\'s streaks! A beautiful journaling companion for your spiritual journey.\n\n$url',
                );
                await _incrementStars(100);
              },
              backgroundColor: const Color(0xFFE91E63),
              depthColor: const Color(0xFFAD1457),
              radius: 16,
              height: 56,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, size: 20, color: AppTheme.starWhite),
                  SizedBox(width: 10),
                  Text(
                    'Share with Friends +100 ⭐',
                    style: TextStyle(
                      color: AppTheme.starWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _subscribeCard(),
            DuoButton(
              onPressed: _openWhatsApp,
              backgroundColor: const Color(0xFF25D366),
              depthColor: const Color(0xFF128C7E),
              radius: 16,
              height: 56,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_rounded, size: 20, color: AppTheme.starWhite),
                  SizedBox(width: 10),
                  Text(
                    'Join WhatsApp Group +100 ⭐',
                    style: TextStyle(
                      color: AppTheme.starWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _debugCard(),
            const SizedBox(height: 16),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    return DuoButton(
      onPressed: _toggleNotifications,
      backgroundColor: const Color(0xFFFFC107),
      depthColor: const Color(0xFFE6A800),
      radius: 16,
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.notifications_active_rounded, size: 20, color: Color(0xFF1A1A1A)),
          SizedBox(width: 10),
          Text(
            'Enable Reminders +100 ⭐',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
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
          _buildToggleRow(
            icon: Icons.music_note_rounded,
            label: 'Background Music',
            subtitle: '1am study session • lofi',
            value: _musicEnabled,
            onChanged: (val) async {
              await BackgroundMusicService().setMusicEnabled(val);
              if (val) {
                // Ensure study track is playing when re-enabled
                await BackgroundMusicService().play('tunes/1_A.M_Study_Session_lofi_hip_hop_5min.m4a');
              }
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

    return Column(
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

  // ── SUBSCRIPTION CARD ──────────────────────────────────────────────────────

  Widget _subscribeCard() {
    // Email-only membership: show only when the user has no email yet.
    // Spacing lives inside so no gap remains when hidden.
    final email = _currentUser?.email ?? '';
    if (email.isNotEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        DuoButton(
          onPressed: _openRegistration,
          backgroundColor: Colors.white,
          depthColor: Colors.black,
          borderGradientColors: kRainbowBorderColors,
          animateBorder: true,
          radius: 16,
          height: 56,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add_rounded, color: Colors.black, size: 20),
              SizedBox(width: 10),
              Text(
                'Complete registration',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _openRegistration() async {
    if (!mounted) return;
    HapticFeedback.lightImpact();
    final email = _currentUser?.email ?? '';
    if (email.isNotEmpty) return;
    await showCompleteRegistrationSheet(context);
    if (mounted) setState(() {});
  }

  // ── DEBUG ───────────────────────────────────────────────────────────────────

  Widget _buildDebugInsightsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        _buildProfileRow('Insights', '${_insightCards.length} loaded${InsightService.lastFetchError != null ? " — error: ${InsightService.lastFetchError}" : ''}'),
        if (_insightCards.isNotEmpty)
          ..._insightCards.asMap().entries.map((e) {
            final i = e.key;
            final c = e.value;
            final snippet = c.type == 'personalized_insight'
                ? (c.insight ?? c.quote ?? '').toString()
                : c.type == 'surah_guidance'
                    ? '${c.surahName ?? ''} ${c.ayahNumber != null ? '${c.ayahNumber}' : ''} — ${(c.english ?? '').toString()}'
                    : '${c.taskTitle ?? ''} — ${(c.lesson ?? '').toString()}';
            return Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: _buildProfileRow('#${i + 1}', '${c.type}: ${snippet.length > 120 ? '${snippet.substring(0, 120)}…' : snippet}'),
            );
          }),
      ],
    );
  }

  Widget _debugCard() {
    return GestureDetector(
      onTap: () => setState(() => _debugExpanded = !_debugExpanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bug_report_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'DEBUG',
                    style: const TextStyle(
                      color: AppTheme.starWhite,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _debugExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: Colors.redAccent.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ],
              ),
              if (_debugExpanded) ...[
                const SizedBox(height: 20),
                _buildStatusDot('Server', _serverStatus),
                _buildStatusDot('Database', _dbStatus),
                _buildProfileRow('Auth', _debugAuth),
                _buildProfileRow('Trial', _debugTrial),
                _buildProfileRow('Shop cache', _debugShopCache),
                _buildProfileRow('Last Sync', _lastSync),
                if (_debugLastError.isNotEmpty)
                  _buildProfileRow('Last Error', _debugLastError, valueColor: Colors.redAccent),
                const AuthDebugCard(),
                _buildDebugInsightsSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDot(String label, String status) {
    final dotColor = status == 'green'
        ? const Color(0xFF4CAF50)
        : status == 'red'
            ? const Color(0xFFE53935)
            : const Color(0xFFFFC107);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(
            color: AppTheme.ghostSilver, fontSize: 14, fontWeight: FontWeight.w500,
          )),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(
            color: AppTheme.ghostSilver, fontSize: 14, fontWeight: FontWeight.w500,
          )),
          const SizedBox(width: 12),
          Flexible(child: Text(value, textAlign: TextAlign.end, style: TextStyle(
            color: valueColor ?? AppTheme.starWhite, fontSize: 14, fontWeight: FontWeight.w700,
          ))),
        ],
      ),
    );
  }

  Future<void> _pickWidget() async {
    if (!context.mounted) return;

    if (kIsWeb) {
      await _installPwa();
      return;
    }

    await hw.loadLibrary();
    final supported = await hw.HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (!supported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Long-press your home screen → Widgets → Meowmin to add it.'),
          backgroundColor: Color(0xFF311B92),
        ),
      );
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                'Choose Widget Size',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.widgets_rounded, color: AppTheme.neonPurple),
              title: const Text('2×2 Widget'),
              subtitle: const Text('Compact streak display'),
              onTap: () => Navigator.pop(ctx, 'portrait'),
            ),
            ListTile(
              leading: const Icon(Icons.widgets_rounded, color: AppTheme.neonPurple),
              title: const Text('2×4 Widget (Landscape)'),
              subtitle: const Text('Wide streak display'),
              onTap: () => Navigator.pop(ctx, 'landscape'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    final streak = await StreakService.getDisplayStreak();
    await WidgetService.updateStreakWidget(streak);
    await hw.HomeWidget.requestPinWidget(
      androidName: choice == 'portrait' ? 'StreakWidgetProvider' : 'StreakWidgetLandscapeProvider',
      name: choice == 'portrait' ? 'StreakWidgetProvider' : 'StreakWidgetLandscapeProvider',
    );
    if (mounted) {
      await _incrementStars(100);
    }
    if (!context.mounted) return;
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

  Future<void> _installPwa() async {
    if (PwaInstallService.isStandalone) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meowmin is already installed on your home screen.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Show browser-specific install guide dialog
    if (!context.mounted) return;
    await showPwaInstallDialog(context);
    await _incrementStars(100);
  }

  String _fmtTrial(int ms) {
    final totalSec = ms ~/ 1000;
    if (totalSec <= 0) return 'expired';
    final min = totalSec ~/ 60;
    final sec = totalSec % 60;
    if (min >= 60) {
      final h = min ~/ 60;
      final m = min % 60;
      return '${h}h ${m}m left';
    }
    return '${min}m ${sec}s left';
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
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadStats();
    }
  }
}
