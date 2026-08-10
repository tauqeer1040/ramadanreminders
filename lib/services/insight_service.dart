import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/api_client.dart';

/// A single resolved AI insight card ready to be displayed on the Quran page.
class InsightCard {
  static final RegExp _leadingEmoji = RegExp(
    r'^[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{2B00}-\u{2BFF}\u{2190}-\u{21FF}\u{2300}-\u{23FF}\u{2B50}\u{200D}]+',
    unicode: true,
  );

  final String date;
  final String type;

  // personalized_insight
  final String? journalExcerpt;
  final String? insight;
  final String? quote;
  final String? reference;

  // surah_guidance
  final String? explanation;
  final String? arabicVerse;
  final String? transliteration;
  final String? english;
  final String? surahName;
  final int? ayahNumber;
  final String? audioUrl;

  // story_and_task
  final String? story;
  final String? storyReference;
  final String? lesson;
  final String? taskTitle;
  final String? taskDescription;

  InsightCard({
    required this.date,
    this.type = 'personalized_insight',
    this.journalExcerpt,
    this.insight,
    this.quote,
    this.reference,
    this.explanation,
    this.arabicVerse,
    this.transliteration,
    this.english,
    this.surahName,
    this.ayahNumber,
    this.audioUrl,
    this.story,
    this.storyReference,
    this.lesson,
    this.taskTitle,
    this.taskDescription,
  });

  Map<String, dynamic> toJson() => {
        'date': date,
        'type': type,
        'journalExcerpt': journalExcerpt,
        'insight': insight,
        'quote': quote,
        'reference': reference,
        'explanation': explanation,
        'arabicVerse': arabicVerse,
        'transliteration': transliteration,
        'english': english,
        'surahName': surahName,
        'ayahNumber': ayahNumber,
        'audioUrl': audioUrl,
        'story': story,
        'storyReference': storyReference,
        'lesson': lesson,
        'taskTitle': taskTitle,
        'taskDescription': taskDescription,
      };

  factory InsightCard.fromJson(Map<String, dynamic> json) {
    String? clean(String? s) {
      if (s == null) return null;
      return s.replaceFirst(_leadingEmoji, '').trim();
    }

    final t = json['type'] as String? ?? '';
    // Backward compat: old format cards without type get mapped to personalized_insight
    if (t.isEmpty) {
      return InsightCard(
        date: json['date'] ?? '',
        type: 'personalized_insight',
        journalExcerpt: clean(json['journalExcerpt'] as String?),
        insight: clean(json['insight'] as String? ?? json['greeting'] as String?),
        quote: clean(json['quote'] as String?),
        reference: json['reference'] as String?,
      );
    }
    return InsightCard(
      date: json['date'] ?? '',
      type: t,
      journalExcerpt: clean(json['journalExcerpt'] as String?),
      insight: clean(json['insight'] as String?),
      quote: clean(json['quote'] as String?),
      reference: json['reference'] as String?,
      explanation: clean(json['explanation'] as String?),
      arabicVerse: json['arabicVerse'] as String?,
      transliteration: json['transliteration'] as String?,
      english: json['english'] as String?,
      surahName: json['surahName'] as String?,
      ayahNumber: json['ayahNumber'] as int?,
      audioUrl: json['audioUrl'] as String?,
      story: clean(json['story'] as String?),
      storyReference: json['storyReference'] as String?,
      lesson: clean(json['lesson'] as String?),
      taskTitle: json['taskTitle'] as String?,
      taskDescription: json['taskDescription'] as String?,
    );
  }
}

class InsightService {
  static final _auth = FirebaseAuth.instance;
  static final String _backendUrl = AppConstants.backendUrl;

  static const String _dailyContentKey = 'daily_content_cache';

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<void> invalidateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dailyContentKey);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> _loadCachedDailyContent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_dailyContentKey);
      if (raw == null) return null;
      final parsed = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (parsed['_date'] != _today()) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveDailyContent(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      payload['_date'] = _today();
      await prefs.setString(_dailyContentKey, jsonEncode(payload));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> fetchDailyContent({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final cached = await _loadCachedDailyContent();
    if (!forceRefresh && cached != null) {
      return cached;
    }

    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/user/${user.uid}/daily-content?day=${_today()}'),
        headers: await ApiClient.authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final payload = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        await _saveDailyContent(payload);
        return payload;
      }
    } catch (_) {}

    return cached;
  }

  static Future<List<InsightCard>?> loadCacheInternal() async {
    final cached = await _loadCachedDailyContent();
    if (cached == null) return null;
    final cardsRaw = cached['insightCards'];
    if (cardsRaw is List) {
      return cardsRaw
          .map((e) => InsightCard.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return null;
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
      if (cards.isNotEmpty) return cards;
    }

    return [];
  }

  /// Fetches the AI insight cards for a single journal from the backend.
  /// Returns an empty list when the journal has no completed AI insights
  /// (unsynced, pending, or failed) or the user is anonymous.
  static Future<List<InsightCard>> fetchJournalInsightCards(String journalId) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous || journalId.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.parse('$_backendUrl/journal/${Uri.encodeComponent(journalId)}'),
        headers: await ApiClient.authHeaders(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      final payload = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      final summary = payload['insight']?['summary'] as String?;
      if (summary == null || summary.isEmpty) return [];

      final parsed = Map<String, dynamic>.from(jsonDecode(summary) as Map);
      final cardsRaw = parsed['cards'];
      if (cardsRaw is! List) return [];

      return cardsRaw
          .map((e) => InsightCard.fromJson(Map<String, dynamic>.from(e as Map)))
          .where((c) => c.type.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns cached insight cards without hitting the network.
  /// Used to ensure scratch cards always have content to display.
  static Future<List<InsightCard>> getCachedInsights({int limit = 3}) async {
    final cached = await _loadCachedDailyContent();
    if (cached == null) return [];
    final cardsRaw = cached['insightCards'];
    if (cardsRaw is List) {
      return cardsRaw
          .map((e) => InsightCard.fromJson(Map<String, dynamic>.from(e as Map)))
          .take(limit)
          .toList();
    }
    return [];
  }
}
