class ShopItem {
  final String id;
  final String name;
  final String thumbnailUrl;
  final String imageUrl;
  final int cost;
  final String localAsset;

  /// Non-empty for real-money items (e.g. '$0.99'). Empty = star purchase.
  final String priceLabel;

  /// Pinned items stay first in the grid regardless of owned-sort.
  final bool pinned;

  const ShopItem({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    required this.imageUrl,
    required this.cost,
    this.localAsset = '',
    this.priceLabel = '',
    this.pinned = false,
  });

  /// True for the Streak Shield consumable (real-money, count-based).
  bool get isShield => id == 'shield';

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
    id: json['id'] as String,
    name: json['name'] as String,
    thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    imageUrl: json['imageUrl'] as String? ?? '',
    cost: json['cost'] as int? ?? 100,
    localAsset: json['localAsset'] as String? ?? '',
    priceLabel: json['priceLabel'] as String? ?? '',
    pinned: json['pinned'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'thumbnailUrl': thumbnailUrl,
    'imageUrl': imageUrl,
    'cost': cost,
    'localAsset': localAsset,
    'priceLabel': priceLabel,
    'pinned': pinned,
  };
}
