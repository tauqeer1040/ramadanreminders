import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/analytics_service.dart';
import '../../services/favorites_service.dart';
import '../../services/insight_service.dart';
import '../../services/journal_service.dart';
import '../../services/revenuecat_service.dart';
import '../../services/star_service.dart';
import '../../services/streak_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import 'deferred_lottie.dart';
import 'duo_button.dart';
import 'gated_scratcher.dart';
import 'glass_container.dart';
import 'monthly_line_chart.dart';
import '../../utils/image_urls.dart';

/// Post-purchase delight sheet AND expired-trial hard gate, styled like
/// onboarding. Two modes:
/// * [MaxSheetMode.welcome]: "thank you for getting Max" + 3-day progress +
///   benefits. Shown ONCE per purchase (flag keyed by purchase date), right
///   after the paywall reports purchased/restored. Dismissible.
/// * [MaxSheetMode.expired]: "Thank You for trying Meowmin" + same stats +
///   blurred scratch teaser + white Get Max CTA + Restore. Non-dismissible
///   (PopScope + no drag); pops `true` once the user unlocks Max.
enum MaxSheetMode { welcome, expired }

class MaxWelcomeSheet extends StatefulWidget {
  final Future<void> Function(String email)? onEmailSaved;
  final MaxSheetMode mode;

  /// Expired mode only: launches the paywall. Returns true when Max is
  /// unlocked afterwards (sheet pops with `true`).
  final Future<bool> Function()? onGetMax;

  const MaxWelcomeSheet({
    super.key,
    this.onEmailSaved,
    this.mode = MaxSheetMode.welcome,
    this.onGetMax,
  });

  /// Consumes a pending purchase flag (set by [RevenueCatService] on every
  /// purchase, renewal staging, or restore) and shows the sheet once for
  /// it. Safe to call from any post-purchase path — including app launch,
  /// which covers web checkout and restores. Returns true when shown.
  /// Restores stage a forced flag: the sheet shows even for an already-seen
  /// purchase, but the +100 star bonus is not re-awarded on repeats.
  static Future<bool> showIfPending(BuildContext context) async {
    final key = await RevenueCatService.consumeWelcomePending();
    if (key == null || key.isEmpty) return false;
    if (!context.mounted) return false;
    final forced = await RevenueCatService.consumeWelcomeForce();
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('max_welcome_seen_$key') ?? false;
    if (seen && !forced) return false;
    if (!context.mounted) return false;
    // Production path only (debug previews call showOnce directly and
    // never award): +100 star Max bonus, once per purchase key.
    if (!seen) await StarService.awardMaxBonus(key);
    if (!context.mounted) return false;
    return showOnce(
      context,
      purchaseKey: key,
      onEmailSaved: UserService.updateEmail,
      ignoreSeen: forced,
    );
  }

  /// Shows the sheet once per [purchaseKey] (product + latest purchase
  /// date, so renewals and re-subscribes show again). [ignoreSeen] bypasses
  /// the dedupe for restores. Returns true when actually shown.
  static Future<bool> showOnce(
    BuildContext context, {
    required String purchaseKey,
    Future<void> Function(String email)? onEmailSaved,
    bool ignoreSeen = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final seenKey = 'max_welcome_seen_$purchaseKey';
    if (!ignoreSeen && (prefs.getBool(seenKey) ?? false)) return false;
    if (!context.mounted) return false;
    final sheetFuture = showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => GlassContainer(
        sigmaX: 28,
        sigmaY: 28,
        tint: Colors.white.withValues(alpha: 0.12),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        child: MaxWelcomeSheet(onEmailSaved: onEmailSaved),
      ),
    );
    // Purchase delight: confetti bursts as the sheet opens. Fire-and-forget
    // off the sheet future so a confetti failure can never block the sheet.
    try {
      Confetti.launch(
        context,
        options: const ConfettiOptions(particleCount: 60, spread: 80, y: 0.4),
      );
    } catch (_) {}
    await sheetFuture;
    await prefs.setBool(seenKey, true);
    await RevenueCatService.noteWelcomeShown(purchaseKey);
    try {
      AnalyticsService.instance.logEvent('max_welcome_shown', params: {});
    } catch (_) {}
    return true;
  }

  @override
  State<MaxWelcomeSheet> createState() => _MaxWelcomeSheetState();

  /// Expired-trial hard gate. Non-dismissible in production (no drag,
  /// tap-outside, or back-button escape); debug builds stay dismissable
  /// for fast iteration. Pops `true` once Max is unlocked (purchase or
  /// restore) so the caller can route into the app. Stats load from local
  /// data, so the value recap works without an account.
  static Future<bool> showExpired(
    BuildContext context, {
    Future<bool> Function()? onGetMax,
  }) async {
    if (!context.mounted) return false;
    try {
      AnalyticsService.instance.logEvent('max_expired_shown', params: {});
    } catch (_) {}
    final unlocked = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      // Debug builds stay dismissable for fast iteration; production
      // locks the wall (no drag, no tap-outside, no back-button escape).
      isDismissible: kDebugMode,
      enableDrag: kDebugMode,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => PopScope(
        canPop: kDebugMode,
        child: GlassContainer(
          sigmaX: 28,
          sigmaY: 28,
          tint: Colors.white.withValues(alpha: 0.12),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          child: MaxWelcomeSheet(
            mode: MaxSheetMode.expired,
            onGetMax: onGetMax,
            onEmailSaved: UserService.updateEmail,
          ),
        ),
      ),
    );
    return unlocked == true;
  }
}

class _MaxWelcomeSheetState extends State<MaxWelcomeSheet> {
  String _name = 'friend';
  String? _planTitle;
  bool _isLifetime = false;
  bool _hasEmail = false;
  int _journals = 0;
  int _words = 0;
  int _favs = 0;
  int _insights = 0;
  int _streak = 1;
  int _stars = 0;
  List<int> _monthly = List.filled(12, 0);
  bool _loaded = false;
  bool _savingEmail = false;
  bool _emailSaved = false;
  bool _busy = false;
  bool _restoring = false;
  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  /// Challenge-language title from the purchased product. Never billing
  /// terms ("monthly"/"yearly"): monthly|weekly → 30-day, four-month → 
  /// 4-month, year|annual → 1-year, lifetime → mindful-Duniya line.
  static bool _resolveIsLifetime() {
    try {
      final info = RevenueCatService.instance.cachedCustomerInfo;
      final productId = info?.entitlements
              .active[RevenueCatService.entitlementId]?.productIdentifier
              .toLowerCase() ??
          '';
      return productId.contains('lifetime');
    } catch (_) {
      return false;
    }
  }

  static String? _resolvePlanTitle() {
    try {
      final info = RevenueCatService.instance.cachedCustomerInfo;
      final productId = info?.entitlements
              .active[RevenueCatService.entitlementId]?.productIdentifier
              .toLowerCase() ??
          '';
      if (productId.isEmpty) return null;
      if (productId.contains('lifetime')) return null; // Duniya line instead
      if (productId.contains('four-month') || productId.contains('four_month')) {
        return 'Your 4-month challenge';
      }
      if (productId.contains('year') || productId.contains('annual')) {
        return 'Your 1-year challenge';
      }
      if (productId.contains('month') || productId.contains('week') || productId.contains('day')) {
        return 'Your 30-day challenge';
      }
      return 'Your Max journey';
    } catch (_) {
      return null;
    }
  }

  static String _resolveName(SharedPreferences prefs) {
    final onboard = (prefs.getString('onboarding_displayName') ?? '').trim();
    if (onboard.isNotEmpty) return onboard.split(' ').first;
    final user = FirebaseAuth.instance.currentUser;
    final display = (user?.displayName ?? '').trim();
    if (display.isNotEmpty) return display.split(' ').first;
    final email = (user?.email ?? '').trim();
    if (email.contains('@')) return email.split('@').first;
    return 'friend';
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final results = await Future.wait([
        JournalService.getAllLocalJournals(),
        FavoritesService.getFavorites(),
        InsightService.loadRevealedIds(),
        StreakService.getDisplayStreak(),
      ]);
      final journals = results[0] as List<Map<String, String>>;
      final favs = results[1] as List;
      final revealed = results[2] as Set<String>;
      final streak = results[3] as int;

      int words = 0;
      final now = DateTime.now();
      final monthly = List<int>.filled(12, 0);
      for (final j in journals) {
        final text = (j['text'] ?? '').trim();
        if (text.isNotEmpty) {
          words += text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
        }
        try {
          final d = DateTime.parse(j['date'] ?? '');
          if (d.year == now.year) monthly[d.month - 1]++;
        } catch (_) {}
      }

      final stars = prefs.getInt('total_stars') ?? 0;
      final fbEmail = (FirebaseAuth.instance.currentUser?.email ?? '').trim();
      final savedEmail = (prefs.getString('onboarding_email') ?? '').trim();
      if (mounted) {
        setState(() {
          _name = _resolveName(prefs);
          _planTitle = _resolvePlanTitle();
          _isLifetime = _resolveIsLifetime();
          _hasEmail = fbEmail.contains('@') || savedEmail.contains('@');
          _journals = journals.length;
          _words = words;
          _favs = favs.length;
          _insights = revealed.length;
          _streak = streak < 1 ? 1 : streak;
          _stars = stars;
          _monthly = monthly;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  /// Plan-aware title: challenge language, never billing terms. Lifetime
  /// gets the Duniya line. Unknown plan falls back to the thank-you line
  /// itself (so [_showThanksLine] hides the duplicate subheading).
  /// Expired mode gets the trying-line — no entitlement to resolve from.
  String get _title {
    if (widget.mode == MaxSheetMode.expired) {
      return 'Thank you for trying Meowmin, $_name!';
    }
    if (_isLifetime) return 'Towards a more mindful Duniya, $_name!';
    final plan = _planTitle;
    if (plan == null) return 'Thank you for getting Max, $_name!';
    return '$plan starts now, $_name!';
  }

  bool get _showThanksLine =>
      widget.mode != MaxSheetMode.expired &&
      (_isLifetime || _planTitle != null);

  String get _subtitle => widget.mode == MaxSheetMode.expired
      ? "Here's what 3 days built — keep it going with Max."
      : 'Look how far 3 days took you — imagine where daily reflection carries you next.';

  static String _fmtNum(int n) {
    if (n >= 1000) {
      final k = n / 1000;
      return '${k.toStringAsFixed(k < 10 ? 1 : 0)}K';
    }
    return '$n';
  }

  Future<void> _saveEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@') || _savingEmail) return;
    setState(() => _savingEmail = true);
    try {
      await widget.onEmailSaved?.call(email);
      if (mounted) setState(() => _emailSaved = true);
    } catch (_) {
      if (mounted) setState(() => _savingEmail = false);
    }
  }

  /// Expired mode: launch the paywall, pop `true` when Max unlocks.
  Future<void> _handleGetMax() async {
    if (_busy) return;
    setState(() => _busy = true);
    bool unlocked = false;
    try {
      unlocked = await widget.onGetMax?.call() ?? false;
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    if (unlocked && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// Expired mode: restore from the store, pop `true` when Max unlocks.
  Future<void> _handleRestore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    try {
      final info = await RevenueCatService.instance.restorePurchases();
      // restorePurchases already staged a FORCED thank-you when entitled.
      if (RevenueCatService.instance.hasActiveEntitlement(info)) {
        if (mounted) Navigator.of(context).pop(true);
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No purchases found to restore')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No purchases found to restore')),
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final expired = widget.mode == MaxSheetMode.expired;
    // Both modes show the same 3 scratch faces; expired locks them,
    // welcome (thank-you) shows them clear with no lock icon.
    final teasers = scratchCardUrls().take(3).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        // Scrollable: stats components make the sheet taller than one screen.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 18),
              Image.asset(
                'assets/photos/mascot/face.webp',
                width: 76,
                height: 76,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.auto_awesome_rounded,
                  color: cs.onSurface,
                  size: 44,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (_showThanksLine) ...[
                const SizedBox(height: 4),
                Text(
                  'Thank you for getting Max.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.7),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              if (_loaded) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _streakCard(context)),
                    const SizedBox(width: 10),
                    Expanded(child: _starsCard()),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _graphCard()),
                    const SizedBox(width: 10),
                    Expanded(child: _insightsCard()),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.neonPurple.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.neonPurple.withValues(alpha: 0.45),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Benefit(
                      lead: 'Unlimited word count ',
                      rest: '— the 280-character cap is gone',
                    ),
                    _Benefit(
                      lead: 'Fresh AI insights ',
                      rest: 'queued every day',
                    ),
                    _Benefit(
                      lead: 'Streak shields ',
                      rest: '— never lose your progress',
                    ),
                    _Benefit(
                      lead: 'Private, encrypted diary ',
                      rest: 'across all 114 surahs',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!_hasEmail) ...[
                if (_emailSaved)
                  const Text(
                    'JazakAllah khair — your journey recap will arrive by email 🤍',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.starGold, fontSize: 13, fontWeight: FontWeight.w700),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: cs.onSurface, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Email for your journey recap (optional)',
                            hintStyle: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                          ),
                          onSubmitted: (_) => _saveEmail(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Fixed width: DuoButton's depth stack needs bounded
                      // constraints, which a bare Row child doesn't provide.
                      SizedBox(
                        width: 52,
                        child: DuoButton(
                          onPressed: _saveEmail,
                          backgroundColor: Colors.white,
                          depthColor: Colors.black,
                          radius: 14,
                          height: 48,
                          child: _savingEmail
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.black, size: 20),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
              ],
              if (!expired && teasers.isNotEmpty) ...[
                SizedBox(
                  height: 132,
                  child: Row(
                    children: [
                      for (var i = 0; i < teasers.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: GatedScratcher(
                            imageUrl: teasers[i],
                            showLock: false,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (expired) ...[
                SizedBox(
                  height: 132,
                  child: Row(
                    children: [
                      for (var i = 0; i < teasers.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          child: GatedScratcher(
                            imageUrl: teasers[i],
                            onUnlockTap: _handleGetMax,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Join the challenge to continue using Meowmin',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              if (expired) ...[
                SizedBox(
                  width: double.infinity,
                  child: DuoButton(
                    onPressed: _handleGetMax,
                    backgroundColor: Colors.white,
                    depthColor: Colors.black,
                    borderGradientColors: kRainbowBorderColors,
                    animateBorder: true,
                    radius: 16,
                    height: 54,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Text(
                            'Get Max',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: TextButton(
                    onPressed: _restoring ? null : _handleRestore,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _restoring
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Restore Purchases',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ] else
                DuoButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                  backgroundColor: AppTheme.neonPurple,
                  depthColor: const Color(0xFF6A00FF),
                  radius: 16,
                  height: 54,
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// STARS card: gold-tinted glass + star + count, beside the streak card.
  /// Includes the +100 Max purchase bonus (awarded once per purchase).
  Widget _starsCard() {
    const fg = Color(0xFFF1F1F1);
    return GlassContainer(
      sigmaX: 12,
      sigmaY: 12,
      tint: AppTheme.starGold.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.18),
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'STARS',
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppTheme.starGold,
                size: 40,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    _fmtNum(_stars),
                    style: const TextStyle(
                      color: fg,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'incl. +100 Max bonus',
            style: TextStyle(color: fg, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// STREAK card: purple glass + fire + big count (half-width beside stars).
  Widget _streakCard(BuildContext context) {
    const fg = Color(0xFFF1F1F1);
    return GlassContainer(
      sigmaX: 12,
      sigmaY: 12,
      tint: const Color(0xFF9D50FF).withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.18),
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: DeferredLottie(
                  asset: 'assets/photos/elements/streak_fire.json',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.local_fire_department_rounded,
                    color: Color(0xFFFF6B35),
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    '$_streak',
                    style: const TextStyle(
                      color: fg,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'day streak',
            style: TextStyle(color: fg, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// GRAPH card: the exact stats ANALYTICS painter ([MonthlyLinePainter]),
  /// fed with cumulative monthly totals so the line only ever rises
  /// gradually — the same chart language as the stats bento.
  Widget _graphCard() {
    const bg = Color(0xFF2A2A2A);
    const fg = Color(0xFFF1F1F1);
    final cumulative = <int>[];
    var running = 0;
    for (final m in _monthly) {
      running += m;
      cumulative.add(running);
    }
    final yearTotal = running;
    return Container(
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
              const Text(
                'GRAPH',
                style: TextStyle(
                  color: fg,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                '${_fmtNum(yearTotal)}+',
                style: const TextStyle(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: CustomPaint(
              painter: MonthlyLinePainter(
                data: cumulative,
                lineColor: const Color(0xFFF5E6A3),
                currentMonth: DateTime.now().month - 1,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('J-M', style: TextStyle(color: fg, fontSize: 8)),
              Text('A-J', style: TextStyle(color: fg, fontSize: 8)),
              Text('J-S', style: TextStyle(color: fg, fontSize: 8)),
              Text('O-D', style: TextStyle(color: fg, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  /// INSIGHTS card: dark box with the entries/words/revealed/favs breakdown.
  Widget _insightsCard() {
    const bg = Color(0xFF2A2A2A);
    const fg = Color(0xFFF1F1F1);
    Widget row(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: fg, fontSize: 11.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: fg,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INSIGHTS',
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          row('Entries', '$_journals'),
          row('Words', _fmtNum(_words)),
          row('Revealed', '$_insights'),
          row('Favs', '$_favs'),
        ],
      ),
    );
  }
}

/// One gold-box benefit bullet: bold lead + rest.
class _Benefit extends StatelessWidget {
  final String lead;
  final String rest;

  const _Benefit({required this.lead, required this.rest});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✓  ', style: TextStyle(color: AppTheme.starWhite, fontSize: 13.5, fontWeight: FontWeight.w900)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.85),
                  fontSize: 13.5,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: lead,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: rest),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
