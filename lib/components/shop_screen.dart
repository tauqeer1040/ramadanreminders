import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class _ShopItem {
  final String id;
  final String name;
  final String asset;
  final int cost;
  const _ShopItem({required this.id, required this.name, required this.asset, required this.cost});
}

const _shopItems = [
  _ShopItem(id: 'shop_1', name: 'Delicate Translucent Flower', asset: 'assets/photos/images/Delicate Translucent Flower.png', cost: 100),
  _ShopItem(id: 'shop_2', name: 'Orange Bloom', asset: 'assets/photos/images/DelicateOrangeFlowerinBloom.jpeg', cost: 100),
  _ShopItem(id: 'shop_3', name: 'Ethereal Flower in Motion', asset: 'assets/photos/images/Ethereal Flower in Motion.png', cost: 100),
  _ShopItem(id: 'shop_4', name: 'Ethereal Flower', asset: 'assets/photos/images/Ethereal Flower.png', cost: 100),
  _ShopItem(id: 'shop_5', name: 'Ethereal Flower V2', asset: 'assets/photos/images/Ethereal Flower(1).png', cost: 100),
  _ShopItem(id: 'shop_6', name: 'Glowing Flower', asset: 'assets/photos/images/Ethereal Glowing Flower.png', cost: 100),
  _ShopItem(id: 'shop_7', name: 'Translucent Flower', asset: 'assets/photos/images/Ethereal Translucent Flower.png', cost: 100),
  _ShopItem(id: 'shop_8', name: 'Ethereal Bloom', asset: 'assets/photos/images/EtherealFlower.jpeg', cost: 100),
  _ShopItem(id: 'shop_9', name: 'Ethereal Bloom V2', asset: 'assets/photos/images/EtherealFlower-1-.jpeg', cost: 100),
  _ShopItem(id: 'shop_10', name: 'Ethreial Bloom', asset: 'assets/photos/images/ethreialbloom1.jpeg', cost: 100),
  _ShopItem(id: 'shop_11', name: 'Radiant Flower Glow', asset: 'assets/photos/images/Radiant Flower Glow.png', cost: 100),
  _ShopItem(id: 'shop_12', name: 'Ethereal Bloom V3', asset: 'assets/photos/images/Z5u14ZbqstJ9-Dkw_EtherealFlower-1-.jpeg', cost: 100),
  _ShopItem(id: 'shop_13', name: 'Scratch Card 1', asset: 'assets/photos/images/scratchCards/scratch.jpg', cost: 100),
  _ShopItem(id: 'shop_14', name: 'Scratch Card 2', asset: 'assets/photos/images/scratchCards/scratch (2).jpg', cost: 100),
  _ShopItem(id: 'shop_15', name: 'Scratch Card 3', asset: 'assets/photos/images/scratchCards/scratch (3).jpg', cost: 100),
  _ShopItem(id: 'shop_16', name: 'Scratch Card 4', asset: 'assets/photos/images/scratchCards/scratch (4).jpg', cost: 100),
  _ShopItem(id: 'shop_17', name: 'Scratch Card 5', asset: 'assets/photos/images/scratchCards/scratch (5).jpg', cost: 100),
  _ShopItem(id: 'shop_18', name: 'Scratch Card 6', asset: 'assets/photos/images/scratchCards/scratch (6).jpg', cost: 100),
  _ShopItem(id: 'shop_19', name: 'Scratch Card 7', asset: 'assets/photos/images/scratchCards/scratch (7).jpg', cost: 100),
  _ShopItem(id: 'shop_20', name: 'Scratch Card 8', asset: 'assets/photos/images/scratchCards/scratch (8).jpg', cost: 100),
  _ShopItem(id: 'shop_21', name: 'Scratch Card 9', asset: 'assets/photos/images/scratchCards/scratch (9).jpg', cost: 100),
];

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _stars = 0;
  Set<String> _unlocked = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stars = prefs.getInt('total_stars') ?? 0;
    final raw = prefs.getString('shop_unlocked');
    final unlocked = raw != null ? Set<String>.from(jsonDecode(raw) as List) : <String>{};
    if (mounted) {
      setState(() {
        _stars = stars;
        _unlocked = unlocked;
        _loaded = true;
      });
    }
  }

  Future<void> _purchase(_ShopItem item) async {
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('total_stars', _stars - item.cost);
    _unlocked.add(item.id);
    await prefs.setString('shop_unlocked', jsonEncode(_unlocked.toList()));

    if (mounted) {
      setState(() => _stars -= item.cost);
      HapticFeedback.heavyImpact();
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

  void _showPreview(_ShopItem item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(item.asset, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 0),
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
          child: !_loaded
              ? const Center(child: CircularProgressIndicator(color: AppTheme.neonPurple))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: _shopItems.length,
                  itemBuilder: (context, i) => _ShopCard(
                    item: _shopItems[i],
                    owned: _unlocked.contains(_shopItems[i].id),
                    canAfford: _stars >= _shopItems[i].cost,
                    onPurchase: () => _purchase(_shopItems[i]),
                    onPreview: () => _showPreview(_shopItems[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ShopCard extends StatelessWidget {
  final _ShopItem item;
  final bool owned;
  final bool canAfford;
  final VoidCallback onPurchase;
  final VoidCallback onPreview;

  const _ShopCard({
    required this.item,
    required this.owned,
    required this.canAfford,
    required this.onPurchase,
    required this.onPreview,
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
                  Image.asset(item.asset, fit: BoxFit.cover),
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
