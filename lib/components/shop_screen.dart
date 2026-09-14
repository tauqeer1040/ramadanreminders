import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scratcher/scratcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/shop_item.dart';
import 'widgets/deferred_lottie.dart';
import 'widgets/glass_container.dart';
import '../services/shop_service.dart';
import '../services/streak_service.dart';
import '../services/shield_billing_service.dart';
import '../services/widget_service.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../theme/app_theme.dart';
import '../utils/image_urls.dart';
import 'favorites_page.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<ShopItem> _items = [];
  int _stars = 0;
  Set<String> _unlocked = {};
  bool _loaded = false;
  bool _loadError = false;
  int _shieldCount = 0;
  int _streak = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      ShopService.fetchItems(),
      ShopService.getUnlockedIds(),
      ShopService.getStarBalance(),
      StreakService.getArmedShieldCount(),
      // Friend-boosted display streak (max of local + friend), whichever
      // is highest — same value the home/stats sheets show.
      StreakService.getDisplayStreak(),
    ]);
    if (mounted) {
      final items = results[0] as List<ShopItem>;
      final unlocked = results[1] as Set<String>;
      final sorted = List<ShopItem>.from(items);
      sorted.sort((a, b) {
        if (a.pinned && !b.pinned) return -1;
        if (!a.pinned && b.pinned) return 1;
        final aOwned = unlocked.contains(a.id);
        final bOwned = unlocked.contains(b.id);
        if (aOwned && !bOwned) return -1;
        if (!aOwned && bOwned) return 1;
        return 0;
      });
      setState(() {
        _items = sorted;
        _unlocked = unlocked;
        _stars = results[2] as int;
        _shieldCount = results[3] as int;
        _streak = results[4] as int;
        _loaded = true;
      });
    }
  }

  Future<void> _reloadShieldState() async {
    final results = await Future.wait([
      StreakService.getArmedShieldCount(),
      StreakService.getDisplayStreak(),
    ]);
    if (mounted) {
      setState(() {
        _shieldCount = results[0];
        _streak = results[1];
      });
    }
  }

  bool _isScratchCard(String id) {
    final num = int.tryParse(id.split('_').last) ?? 0;
    return num >= 13 && num <= 21;
  }

  int _randomFlowerId() => Random().nextInt(12) + 1;

  Future<void> _purchase(ShopItem item, [int qty = 1]) async {
    if (item.isShield) {
      await _purchaseShields(qty, restoreIfBroken: true);
      return;
    }
    if (_unlocked.contains(item.id)) return;
    if (_stars < item.cost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough stars! ✍️ Journal to earn more.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final ok = await ShopService.purchaseItem(item.id);
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase failed. Try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    AnalyticsService.instance.logShopPurchase(item.id);
    final stars = await ShopService.getStarBalance();
    if (mounted) {
      setState(() {
        _stars = stars;
        _unlocked.add(item.id);
      });
      HapticFeedback.heavyImpact();

      if (_isScratchCard(item.id)) {
        await _showScratchReveal(item);
      } else {
        Confetti.launch(
          context,
          options: const ConfettiOptions(
            particleCount: 60,
            spread: 360,
            startVelocity: 25,
            gravity: 0.3,
            scalar: 1.2,
            colors: [Colors.amber, Colors.pink, Colors.cyan],
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star_rounded, color: AppTheme.starGold, size: 20),
                const SizedBox(width: 8),
                Text('${item.name} unlocked! ⭐'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      unawaited(WidgetService.refreshWidgetBackground());
    }
  }

  /// Buys ONE Streak Shield ($0.99, single Play Billing sheet). The store
  /// sells shields singly — quantity pickers were removed (Play Billing
  /// consumables re-buy one at a time, and the per-unit sheets confused
  /// pricing). [qty] is clamped to 1 defensively.
  /// Healthy streak (> 1) → arms (auto-protects for 2 days).
  /// Broken streak (== 1) → restores to the longest run.
  Future<void> _purchaseShields(int qty, {required bool restoreIfBroken}) async {
    qty = 1;
    final streak = await StreakService.getDisplayStreak();
    final longest = await StreakService.longestRun();
    if (streak <= 1 && longest <= 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Journal a few days first — there is no streak to protect yet.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    var bought = 0;
    for (var i = 0; i < qty; i++) {
      try {
        await ShieldBillingService.purchaseShield();
        bought++;
        AnalyticsService.instance.logShopPurchase('shield');
      } on ShieldPurchaseCancelled {
        break;
      } on ShieldPurchaseException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
          );
        }
        break;
      }
    }
    if (bought <= 0) return;

    HapticFeedback.heavyImpact();

    if (streak > 1) {
      for (var i = 0; i < bought; i++) {
        await StreakService.armShield(streak);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bought == 1
                  ? 'Streak Shield armed! Your $streak-day streak is protected for 2 days. 🛡️'
                  : '$bought shields armed! They fire automatically if you miss a day. 🛡️',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (restoreIfBroken) {
      for (var i = 0; i < bought; i++) {
        await StreakService.armShield(longest);
      }
      final restored = await StreakService.restoreToLongest();
      if (mounted && restored != null) {
        Confetti.launch(
          context,
          options: const ConfettiOptions(
            particleCount: 80,
            spread: 360,
            startVelocity: 25,
            gravity: 0.3,
            colors: [Colors.amber, Colors.pink, Colors.cyan],
          ),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              bought == 1
                  ? 'Streak restored to $restored days! 🔥'
                  : 'Streak restored to $restored days + ${bought - 1} shield${bought - 1 == 1 ? '' : 's'} armed! 🔥',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    await _reloadShieldState();
  }

  /// Manual restore using an already-held shield (purple button path).
  Future<void> _restoreWithHeldShield() async {
    final restored = await StreakService.restoreToLongest();
    if (!mounted) return;
    if (restored != null) {
      HapticFeedback.heavyImpact();
      Confetti.launch(
        context,
        options: const ConfettiOptions(
          particleCount: 80,
          spread: 360,
          startVelocity: 25,
          gravity: 0.3,
          colors: [Colors.amber, Colors.pink, Colors.cyan],
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Streak restored to $restored days! 🔥'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to restore — your streak is already healthy.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await _reloadShieldState();
  }

  /// Full-view dialog for the Streak Shield, mirroring the item preview
  /// pattern but with a state-aware purple action button.
  Future<void> _showShieldDialog(ShopItem item) async {
    AnalyticsService.instance.logShopItemViewed(item.id);
    final longest = await StreakService.longestRun();
    if (!mounted) return;
    final broken = _streak <= 1 && longest > 1;
    final hasShield = _shieldCount > 0;

    // One universal explanation: what shields are for, how auto-protection
    // works, and how to repair an already-broken streak.
    const subtitle = 'Get streak shields to protect your streak. '
        'If you ever miss a day, a streak shield preserves your streak '
        'automatically for one extra day. If your streak broke, use it to '
        'repair it.';

    const String priceLabel = r'$0.99';

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: GlassContainer(
                  sigmaX: 18,
                  sigmaY: 18,
                  tint: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  padding: EdgeInsets.zero,
                  child: _buildImage(item.imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      color: AppTheme.starWhite,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.ghostSilver,
                      fontSize: 13,
                    ),
                  ),
                  if (hasShield) ...[
                    const SizedBox(height: 6),
                    Text(
                      'You have $_shieldCount shield${_shieldCount == 1 ? '' : 's'} — they activate automatically.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.neonPurple,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (broken && hasShield)
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: MaterialButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _restoreWithHeldShield();
                        },
                        color: AppTheme.neonPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'RESTORE STREAK',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.starWhite,
                          ),
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: MaterialButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _purchaseShields(
                            1,
                            restoreIfBroken: true,
                          );
                        },
                        color: AppTheme.neonPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'BUY SHIELD · $priceLabel',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.starWhite,
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
    );
  }

  Future<void> _showScratchReveal(ShopItem item) async {
    final flowerId = _randomFlowerId();
    final flowerUrl = shopFullUrl(flowerId);
    final overlayUrl = item.imageUrl;
    final ctrl = ConfettiController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: 280,
            height: 380,
            child: Stack(
              children: [
                // Revealed content underneath
                _buildImage(flowerUrl, fit: BoxFit.cover),
                // Confetti
                IgnorePointer(
                  child: Confetti(controller: ctrl, options: const ConfettiOptions(
                    particleCount: 120,
                    spread: 360,
                    startVelocity: 30,
                    gravity: 0.4,
                    colors: [Colors.amber, Colors.pink, Colors.cyan, Colors.white],
                  )),
                ),
                // Scratcher overlay
                Scratcher(
                  brushSize: 35,
                  threshold: 40,
                  onThreshold: () {
                    ctrl.launch();
                    HapticFeedback.heavyImpact();
                  },
                  image: overlayUrl.startsWith('assets/')
                    ? Image.asset(overlayUrl, fit: BoxFit.cover)
                    : Image.network(overlayUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  child: Container(color: Colors.transparent),
                ),
                // Close button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      ctrl.kill();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    ctrl.kill();
  }

  void _showPreview(ShopItem item) {
    AnalyticsService.instance.logShopItemViewed(item.id);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _buildImage(item.imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String url, {BoxFit fit = BoxFit.cover}) {
    if (url.isEmpty) return _imageFallback();
    if (url.startsWith('assets/')) {
      return Image.asset(url, fit: fit, errorBuilder: (_, __, ___) => _imageFallback());
    }
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.white.withValues(alpha: 0.05),
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24)),
        );
      },
      errorBuilder: (_, __, ___) {
        debugPrint('[ShopImage] FAILED: $url');
        return _imageFallback();
      },
    );
  }

  Widget _imageFallback() => Container(
    color: Colors.white.withValues(alpha: 0.05),
    child: const Icon(Icons.broken_image_rounded, color: Colors.white24, size: 32),
  );

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Column(
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
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: ClipOval(
                          child: Image.asset(
                            'assets/photos/mascot/face.webp',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.onSurface, size: 28),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () {},
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
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FavoritesPage()),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.starGold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: AppTheme.starGold,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Shop Header ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shop', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppTheme.starWhite)),
                  const SizedBox(height: 2),
                  Text('Unlock new scratch card faces', style: tt.labelSmall?.copyWith(color: AppTheme.ghostSilver, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.starGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.starGold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: AppTheme.starGold, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      '$_stars',
                      style: const TextStyle(
                        color: AppTheme.starGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _buildBody(),
        ),
      ],
      ),
    );
  }

  Widget _buildShopSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.04),
      highlightColor: Colors.white.withValues(alpha: 0.10),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.78,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: 4,
        itemBuilder: (context, i) => Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (!_loaded) {
      return _buildShopSkeleton();
    }

    if (_loadError && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text('Could not load shop', style: TextStyle(color: Colors.white.withValues(alpha: 0.50))),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() => _loadError = false);
                _load();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.neonPurple,
      backgroundColor: const Color(0xFF1A1A2E),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.78,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final item = _items[i];
          return _ShopCard(
            item: item,
            owned: _unlocked.contains(item.id),
            shieldCount: item.isShield ? _shieldCount : 0,
            canAfford: _stars >= item.cost,
            onPurchase: (qty) => _purchase(item, qty),
            onPreview: () => item.isShield ? _showShieldDialog(item) : _showPreview(item),
            buildImage: _buildImage,
          );
        },
      ),
    );
  }
}

class _ShopCard extends StatefulWidget {
  final ShopItem item;
  final bool owned;
  final int shieldCount;
  final bool canAfford;
  final Future<void> Function(int qty) onPurchase;
  final VoidCallback onPreview;
  final Widget Function(String url, {BoxFit fit}) buildImage;

  const _ShopCard({
    required this.item,
    required this.owned,
    this.shieldCount = 0,
    required this.canAfford,
    required this.onPurchase,
    required this.onPreview,
    required this.buildImage,
  });

  @override
  State<_ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends State<_ShopCard> {
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final item = widget.item;
    final owned = widget.owned;
    final shieldCount = widget.shieldCount;
    final canAfford = widget.canAfford;
    final isShield = item.isShield;
    final showBanner = isShield ? shieldCount > 0 : owned;
    final bannerText = isShield ? 'USE X$shieldCount' : 'OWNED';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isShield
            ? Colors.transparent // shield card: transparent bg (orb art supplies its own backdrop)
            : Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isShield
              ? Colors.white.withValues(alpha: 0.12)
              : owned
                  ? AppTheme.starGold.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: (owned || isShield) ? widget.onPreview : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isShield)
                    // Frosted glass under the cutout orb: the thumbnail bg
                    // is transparent, so the blur tint shows through.
                    Positioned.fill(
                      child: GlassContainer(
                        sigmaX: 18,
                        sigmaY: 18,
                        tint: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.zero,
                        border: Border.all(color: Colors.transparent),
                        padding: EdgeInsets.zero,
                        child: widget.buildImage(item.thumbnailUrl.isNotEmpty
                            ? item.thumbnailUrl
                            : item.imageUrl),
                      ),
                    )
                  else
                    widget.buildImage(item.thumbnailUrl.isNotEmpty ? item.thumbnailUrl : item.imageUrl),
                  if (!owned && !isShield)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: const Icon(Icons.lock_rounded, color: Colors.white38, size: 36),
                    ),
                  if (showBanner)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.starGold.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          bannerText,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: tt.labelMedium?.copyWith(
                    color: AppTheme.starWhite,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  height: 32,
                  child: isShield
                      ? MaterialButton(
                          onPressed: () => widget.onPurchase(1),
                          color: AppTheme.neonPurple,
                          height: 32,
                          minWidth: double.infinity,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.shield_rounded,
                                  size: 14, color: AppTheme.starWhite),
                              const SizedBox(width: 3),
                              Text(
                                item.priceLabel.isNotEmpty
                                    ? item.priceLabel
                                    : r'$0.99',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.starWhite,
                                ),
                              ),
                            ],
                          ),
                        )
                      : owned
                      ? OutlinedButton(
                          onPressed: widget.onPreview,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.starGold.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('VIEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.starGold)),
                        )
                      : MaterialButton(
                          onPressed: () => widget.onPurchase(1),
                          color: canAfford ? AppTheme.neonPurple : Colors.grey[800],
                          height: 32,
                          minWidth: double.infinity,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: AppTheme.starGold),
                              const SizedBox(width: 3),
                              Text(
                                '${item.cost}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.starWhite,
                                ),
                              ),
                            ],
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
}
