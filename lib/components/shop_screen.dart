import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scratcher/scratcher.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import '../models/shop_item.dart';
import '../services/shop_service.dart';
import '../theme/app_theme.dart';
import '../utils/image_urls.dart';
import '../screens/about_screen.dart';
import 'favorites_page.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  List<ShopItem> _items = [];
  int _stars = 0;
  Set<String> _unlocked = {};
  bool _loaded = false;
  bool _loadError = false;

  late AnimationController _wobbleCtrl;
  late CurvedAnimation _wobbleAnim;
  Timer? _wobbleTimer;

  @override
  void initState() {
    super.initState();
    _load();

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

  Future<void> _load() async {
    final results = await Future.wait([
      ShopService.fetchItems(),
      ShopService.getUnlockedIds(),
      ShopService.getStarBalance(),
    ]);
    if (mounted) {
      final items = results[0] as List<ShopItem>;
      final unlocked = results[1] as Set<String>;
      final sorted = List<ShopItem>.from(items);
      sorted.sort((a, b) {
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
        _loaded = true;
      });
    }
  }

  bool _isScratchCard(String id) {
    final num = int.tryParse(id.split('_').last) ?? 0;
    return num >= 13 && num <= 21;
  }

  int _randomFlowerId() => Random().nextInt(12) + 1;

  Future<void> _purchase(ShopItem item) async {
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
    }
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/photos/mascot/hi.webp',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, color: Theme.of(context).colorScheme.onSurface, size: 28),
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

  Widget _buildBody() {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.neonPurple));
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
        itemBuilder: (context, i) => _ShopCard(
          item: _items[i],
          owned: _unlocked.contains(_items[i].id),
          canAfford: _stars >= _items[i].cost,
          onPurchase: () => _purchase(_items[i]),
          onPreview: () => _showPreview(_items[i]),
          buildImage: _buildImage,
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final ShopItem item;
  final bool owned;
  final bool canAfford;
  final VoidCallback onPurchase;
  final VoidCallback onPreview;
  final Widget Function(String url, {BoxFit fit}) buildImage;

  const _ShopCard({
    required this.item,
    required this.owned,
    required this.canAfford,
    required this.onPurchase,
    required this.onPreview,
    required this.buildImage,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: owned
              ? AppTheme.starGold.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: owned ? onPreview : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  buildImage(item.thumbnailUrl.isNotEmpty ? item.thumbnailUrl : item.imageUrl),
                  if (!owned)
                    Container(
                      color: Colors.black.withValues(alpha: 0.55),
                      child: const Icon(Icons.lock_rounded, color: Colors.white38, size: 36),
                    ),
                  if (owned)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.starGold.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'OWNED',
                          style: TextStyle(
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
                  child: owned
                      ? OutlinedButton(
                          onPressed: onPreview,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.starGold.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('VIEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.starGold)),
                        )
                      : MaterialButton(
                          onPressed: onPurchase,
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
