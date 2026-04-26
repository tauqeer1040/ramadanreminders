import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

/// A single resolved AI insight card ready to be displayed on the Quran page.
class InsightCard {
  final String date;
  final String greeting;
  final String insight;
  final String reference;
  final String quote;
  final List<String> tags;

  InsightCard({
    required this.date,
    required this.greeting,
    required this.insight,
    required this.reference,
    required this.quote,
    required this.tags,
  });

  factory InsightCard.fromFirestore(String date, Map<String, dynamic> data) {
    return InsightCard(
      date: date,
      greeting: data['greeting'] ?? '',
      insight: data['insight'] ?? '',
      reference: data['reference'] ?? '',
      quote: data['quote'] ?? '',
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  /// Serialize to JSON map for caching in SharedPreferences.
  Map<String, dynamic> toJson() => {
        'date': date,
        'greeting': greeting,
        'insight': insight,
        'reference': reference,
        'quote': quote,
        'tags': tags,
      };

  factory InsightCard.fromJson(Map<String, dynamic> json) {
    return InsightCard(
      date: json['date'] ?? '',
      greeting: json['greeting'] ?? '',
      insight: json['insight'] ?? '',
      reference: json['reference'] ?? '',
      quote: json['quote'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
    );
  }
}

class InsightService {
  static final _auth = FirebaseAuth.instance;
  static final String _backendUrl = AppConstants.backendUrl;

  static const String _cacheKey = 'insight_cards_cache';
  static const String _cacheDateKey = 'insight_cards_cache_date';
  static const String _dailyContentKey = 'daily_content_cache';
  static const String _dailyContentDateKey = 'daily_content_cache_date';

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<List<InsightCard>?> loadCacheInternal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDate = prefs.getString(_cacheDateKey);
      if (cachedDate != _today()) return null;

      final cachedJson = prefs.getString(_cacheKey);
      if (cachedJson == null) return null;

      final List<dynamic> list = jsonDecode(cachedJson);
      return list.map((e) => InsightCard.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveCache(List<InsightCard> cards) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(cards.map((c) => c.toJson()).toList()));
      await prefs.setString(_cacheDateKey, _today());
    } catch (_) {}
  }

  static Future<void> invalidateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheDateKey);
      await prefs.remove(_dailyContentKey);
      await prefs.remove(_dailyContentDateKey);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadDailyContentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_dailyContentDateKey) != _today()) return null;
      final raw = prefs.getString(_dailyContentKey);
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveDailyContentCache(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dailyContentKey, jsonEncode(payload));
      await prefs.setString(_dailyContentDateKey, _today());
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> fetchDailyContent({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final cached = await loadDailyContentCache();
    if (!forceRefresh && cached != null) {
      return cached;
    }

    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/user/${user.uid}/daily-content?day=${_today()}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final payload = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        await _saveDailyContentCache(payload);
        return payload;
      }
    } catch (_) {}

    return cached;
  }

  /// Returns personalized insight cards from the V2 backend's stored journal AI rows.
  static Future<List<InsightCard>> fetchPersonalizedInsights({
    int limit = 3,
    bool forceRefresh = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final dailyContent = await fetchDailyContent(forceRefresh: forceRefresh);
    final cardsRaw = dailyContent?['insightCards'];
    if (cardsRaw is List) {
      final cards = cardsRaw
          .map((e) => InsightCard.fromJson(Map<String, dynamic>.from(e as Map)))
          .take(limit)
          .toList();
      if (cards.isNotEmpty) {
        await _saveCache(cards);
        return cards;
      }
    }

    final cached = await loadCacheInternal();
    return cached?.take(limit).toList() ?? [];
  }
}
