import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../services/sfx_service.dart';
import '../services/trial_service.dart';
import '../services/widget_service.dart';
import '../core/constants.dart';
import '../screens/manage_account_screen.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'stats_card.dart';
import 'widgets/duo_button.dart';
import 'action_prompt_card.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/about_screen.dart';

class ProfilePage1 extends StatefulWidget {
  const ProfilePage1({super.key});

  @override
  State<ProfilePage1> createState() => _ProfilePage1State();
}

class _ProfilePage1State extends State<ProfilePage1>
    with SingleTickerProviderStateMixin {
  User? _currentUser;
  bool _isLoading = false;
  bool _notificationsGranted = false;
  bool _hasWidget = false;
  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  String _debugTrial = '';
  String _debugAuth = '';
  String _debugShopCache = '';
  String _serverStatus = 'yellow';
  String _dbStatus = 'yellow';
  bool _debugExpanded = false;

  late AnimationController _wobbleCtrl;
  late CurvedAnimation _wobbleAnim;
  Timer? _wobbleTimer;

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _wobbleCtrl.dispose();
    _wobbleTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final prefs = await SharedPreferences.getInstance();

    // Debug info
    final user = AuthService.currentUser;
    final isAnon = user?.isAnonymous ?? true;
    final trialActive = await TrialService.isTrialActive();
    final trialRemainingMs = await TrialService.getRemainingMs();
    final shopCache = prefs.getString('shop_items_cache');
    final shopSize = shopCache != null ? '${(shopCache.length / 1024).toStringAsFixed(1)} KB' : '—';

    // Health check
    String serverStatus = 'yellow';
    String dbStatus = 'yellow';
    try {
      final serverRes = await http
          .get(Uri.parse(AppConstants.backendUrl.replaceAll('/api/v2', '')))
          .timeout(const Duration(seconds: 5));
      serverStatus = serverRes.statusCode == 200 ? 'green' : 'red';
    } catch (_) {
      serverStatus = 'red';
    }
    try {
      final dbRes = await http
          .get(Uri.parse('${AppConstants.backendUrl}/tags'))
          .timeout(const Duration(seconds: 5));
      dbStatus = dbRes.statusCode == 200 ? 'green' : 'red';
    } catch (_) {
      dbStatus = 'red';
    }

    final widgetExists = await WidgetService.hasWidget();

    if (mounted) {
      setState(() {
        _hasWidget = widgetExists;
        _serverStatus = serverStatus;
        _dbStatus = dbStatus;
        _debugAuth = '${user?.uid ?? "—"} (${isAnon ? "anonymous" : "signed-in"})';
        _debugTrial = trialActive ? _fmtTrial(trialRemainingMs) : 'expired';
        _debugShopCache = shopSize;
      });
    }
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

  void _openWhatsApp() async {
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
        onRefresh: _loadStats,
        color: AppTheme.neonPurple,
        backgroundColor: const Color(0xFF1A1A2E),
        child: ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          children: [
            // ── Top Bar: Avatar · Logo · Favorites ──────────────────────────
            SizedBox(
              height: 128,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
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
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            Superwall.shared.registerPlacement('campaign_trigger');
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
                              'assets/photos/elements/meowmin.png',
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
                  onTap: _showPaywall,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.starGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
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
            if (!_hasWidget)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: ActionPromptCard(
                  title: 'Homescreen Widget',
                subtitle:
                    'Add a homescreen widget for one-tap access\nto your daily tasks and streak.',
                buttonText: 'Add Widget +100 ⭐',
                onPressed: () async {
                  final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
                  if (supported) {
                    await HomeWidget.requestPinWidget(
                      androidName: 'StreakWidgetProvider',
                      name: 'StreakWidgetProvider',
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
                  } else {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Long-press your home screen → Widgets → Meowmin Ai Diary to add it.'),
                        backgroundColor: Color(0xFF311B92),
                      ),
                    );
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
                buttonText: 'Set Now +100 ⭐',
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
            DuoButton(
              onPressed: () async {
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
            const SizedBox(height: 16),
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
                    'Join WhatsApp Group',
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

  // ── DEBUG ───────────────────────────────────────────────────────────────────

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

  Widget _buildProfileRow(String label, String value) {
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
          Flexible(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(
            color: AppTheme.starWhite, fontSize: 14, fontWeight: FontWeight.w700,
          ))),
        ],
      ),
    );
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
}
