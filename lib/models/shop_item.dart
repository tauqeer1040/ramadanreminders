class ShopItem {
  final String id;
  final String name;
  final String thumbnailUrl;
  final String imageUrl;
  final int cost;
  final String localAsset;

  const ShopItem({
    required this.id,
    required this.name,
    required this.thumbnailUrl,
    required this.imageUrl,
    required this.cost,
    this.localAsset = '',
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
    id: json['id'] as String,
    name: json['name'] as String,
    thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    imageUrl: json['imageUrl'] as String? ?? '',
    cost: json['cost'] as int? ?? 100,
    localAsset: json['localAsset'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'thumbnailUrl': thumbnailUrl,
    'imageUrl': imageUrl,
    'cost': cost,
    'localAsset': localAsset,
  };
}
