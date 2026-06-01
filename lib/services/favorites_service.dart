import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum FavoriteType { insight, ayah }

class FavoriteItem {
  final FavoriteType type;
  final DateTime savedAt;
  final String? date;
  final String? greeting;
  final String? insight;
  final String? reference;
  final String? quote;
  final List<String>? tags;
  final String? arabic;
  final String? transliteration;
  final String? english;
  final String? surah;
  final int? ayahNumber;
  final String? audioUrl;

  FavoriteItem({
    required this.type,
    required this.savedAt,
    this.date,
    this.greeting,
    this.insight,
    this.reference,
    this.quote,
    this.tags,
    this.arabic,
    this.transliteration,
    this.english,
    this.surah,
    this.ayahNumber,
    this.audioUrl,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'savedAt': savedAt.toIso8601String(),
    'date': date,
    'greeting': greeting,
    'insight': insight,
    'reference': reference,
    'quote': quote,
    'tags': tags,
    'arabic': arabic,
    'transliteration': transliteration,
    'english': english,
    'surah': surah,
    'ayahNumber': ayahNumber,
    'audioUrl': audioUrl,
  };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
    type: FavoriteType.values.byName(json['type']),
    savedAt: DateTime.parse(json['savedAt']),
    date: json['date'],
    greeting: json['greeting'],
    insight: json['insight'],
    reference: json['reference'],
    quote: json['quote'],
    tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
    arabic: json['arabic'],
    transliteration: json['transliteration'],
    english: json['english'],
    surah: json['surah'],
    ayahNumber: json['ayahNumber'],
    audioUrl: json['audioUrl'],
  );
}

class FavoritesService {
  static const String _key = 'favorite_insights';

  static Future<List<FavoriteItem>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => FavoriteItem.fromJson(e)).toList();
  }

  static Future<void> addFavorite(FavoriteItem item) async {
    final favorites = await getFavorites();
    favorites.insert(0, item);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(favorites.map((e) => e.toJson()).toList()));
  }

  static Future<bool> isFavorited(String uniqueKey) async {
    final favorites = await getFavorites();
    return favorites.any((f) => itemKey(f) == uniqueKey);
  }

  static Future<void> removeFavorite(String uniqueKey) async {
    final favorites = await getFavorites();
    favorites.removeWhere((f) => itemKey(f) == uniqueKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(favorites.map((e) => e.toJson()).toList()));
  }

  static String itemKey(FavoriteItem item) {
    if (item.type == FavoriteType.insight) {
      return 'insight|${item.date}|${item.reference}';
    }
    return 'ayah|${item.surah}|${item.ayahNumber}';
  }
}
