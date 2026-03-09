class DhikrItem {
  final String id;
  final String name;
  final String arabic;
  final int target;
  int count;
  int historicalCount;

  DhikrItem({
    required this.id,
    required this.name,
    required this.arabic,
    required this.target,
    this.count = 0,
    this.historicalCount = 0,
  });

  int get total => historicalCount + count;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'arabic': arabic,
    'target': target,
    'count': count,
    'historicalCount': historicalCount,
  };

  factory DhikrItem.fromJson(Map<String, dynamic> json) => DhikrItem(
    id: json['id'] as String,
    name: json['name'] as String,
    arabic: json['arabic'] as String,
    target: json['target'] as int,
    count: json['count'] as int? ?? 0,
    historicalCount: json['historicalCount'] as int? ?? 0,
  );

  DhikrItem copyWith({
    String? id,
    String? name,
    String? arabic,
    int? target,
    int? count,
    int? historicalCount,
  }) => DhikrItem(
    id: id ?? this.id,
    name: name ?? this.name,
    arabic: arabic ?? this.arabic,
    target: target ?? this.target,
    count: count ?? this.count,
    historicalCount: historicalCount ?? this.historicalCount,
  );
}
