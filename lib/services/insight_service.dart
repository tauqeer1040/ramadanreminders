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

  final String? id;
  final String? journalId;

  InsightCard({
    required this.date,
    this.type = 'personalized_insight',
    this.id,
    this.journalId,
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
        'id': id,
        'journalId': journalId,
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
        id: json['id'] as String?,
        journalId: json['journalId'] as String?,
        date: json['date'] ?? '',
        type: 'personalized_insight',
        journalExcerpt: clean(json['journalExcerpt'] as String?),
        insight: clean(json['insight'] as String? ?? json['greeting'] as String?),
        quote: clean(json['quote'] as String?),
        reference: json['reference'] as String?,
      );
    }
    return InsightCard(
      id: json['id'] as String?,
      journalId: json['journalId'] as String?,
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
  static const String _scratchBatchKey = 'scratch_batch_cache';
  static const String revealedIdsKey = 'quran_revealed_ids';

  static String? lastFetchError;

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<void> invalidateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_dailyContentKey);
      await prefs.remove(_scratchBatchKey);
    } catch (_) {}
  }

  static Future<void> invalidateScratchCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_scratchBatchKey);
    } catch (_) {}
  }

  static Future<Set<String>> loadRevealedIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(revealedIdsKey);
      if (raw == null) return {};
      return raw.toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> addRevealedId(String id) async {
    if (id.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final set = await loadRevealedIds();
      set.add(id);
      await prefs.setStringList(revealedIdsKey, set.toList());
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> _loadCachedScratchBatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_scratchBatchKey);
      if (raw == null) return null;
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveScratchBatch(Map<String, dynamic> payload) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_scratchBatchKey, jsonEncode(payload));
    } catch (_) {}
  }

  static bool _isBatchFullyRevealed(List<dynamic> cards, Set<String> revealed) {
    if (cards.isEmpty) return false;
    for (final c in cards) {
      final map = Map<String, dynamic>.from(c as Map);
      final id = map['id'] as String? ?? '';
      if (id.isEmpty || !revealed.contains(id)) return false;
    }
    return true;
  }

  /// 1 journal = 3 cards per deck. Yesterday/today priority, unlimited unread fallback.
  /// Never reloads on every view — returns cached batch unless fully revealed or forceRefresh/new journal.
  static Future<List<InsightCard>> fetchScratchBatch({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    // Try cache first (unless forceRefresh)
    if (!forceRefresh) {
      final cached = await _loadCachedScratchBatch();
      if (cached != null) {
        final cardsRaw = cached['insightCards'];
        if (cardsRaw is List && cardsRaw.isNotEmpty) {
          final revealed = await loadRevealedIds();
          if (!_isBatchFullyRevealed(cardsRaw, revealed)) {
            return cardsRaw
                .map((e) => InsightCard.fromJson(Map<String, dynamic>.from(e as Map)))
                .where((c) => c.type.isNotEmpty)
                .toList();
          }
          // Fully revealed -> fall through to fetch next batch
        }
      }
    }

    // Build exclude list: journalIds that are fully revealed
    final revealed = await loadRevealedIds();
    // Derive journalIds that are fully revealed (all 3 cards of that journal revealed)
    // For v1, we exclude any journal where at least one card id matches and we have 3 revealed for that journal.
    // Simpler: collect journalIds where revealed contains card_ prefix
    final Map<String, int> journalRevealedCount = {};
    for (final id in revealed) {
      // id = card_<journalId>_<idx>
      final m = RegExp(r'^card_(.+)_(\d+)$').firstMatch(id);
      if (m != null) {
        final jid = m.group(1)!;
        journalRevealedCount[jid] = (journalRevealedCount[jid] ?? 0) + 1;
      } else if (id.isNotEmpty) {
        // fallback: treat id itself as journalId if not in card_ format
        journalRevealedCount[id] = (journalRevealedCount[id] ?? 0) + 1;
      }
    }
    final fullyRevealedJournalIds = journalRevealedCount.entries
        .where((e) => e.value >= 3)
        .map((e) => e.key)
        .toList();

    // Attempt up to 5 times in case we keep hitting already-revealed batches
    for (int attempt = 0; attempt < 5; attempt++) {
      final excludeParam = fullyRevealedJournalIds.isEmpty ? '' : '&exclude=${fullyRevealedJournalIds.map(Uri.encodeComponent).join(',')}';
      try {
        final response = await http.get(
          Uri.parse('$_backendUrl/user/${user.uid}/scratch-batch?day=${_today()}$excludeParam'),
          headers: await ApiClient.authHeaders(),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final payload = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
          final cards = payload['insightCards'];
          if (cards is List && cards.isNotEmpty) {
            // Check if this batch is already fully revealed (shouldn't happen due to exclude, but guard)
            if (_isBatchFullyRevealed(cards, revealed)) {
              final jid = payload['journalId'] as String?;
              if (jid != null && jid.isNotEmpty && !fullyRevealedJournalIds.contains(jid)) {
                fullyRevealedJournalIds.add(jid);
                continue;
              }
            }
            lastFetchError = null;
            await _saveScratchBatch(payload);
            return cards
                .map((e) => InsightCard.fromJson(Map<String, dynamic>.from(e as Map)))
                .where((c) => c.type.isNotEmpty)
                .toList();
          }
          // Empty -> no more unread, return empty (will show empty state)
          return [];
        }
        lastFetchError = 'HTTP ${response.statusCode}';
      } catch (e) {
        lastFetchError = e.toString();
      }
      break;
    }

    // Fallback to cached even if fully revealed (show again rather than empty)
    final fallback = await _loadCachedScratchBatch();
    if (fallback != null) {
      final cardsRaw = fallback['insightCards'];
      if (cardsRaw is List) {
        return cardsRaw
            .map((e) => InsightCard.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((c) => c.type.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  static Future<List<InsightCard>?> loadScratchCacheInternal() async {
    final cached = await _loadCachedScratchBatch();
    if (cached == null) return null;
    final cardsRaw = cached['insightCards'];
    if (cardsRaw is List) {
      return cardsRaw
          .map((e) => InsightCard.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return null;
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
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final payload = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        lastFetchError = null;
        final cards = payload['insightCards'];
        // Never poison the local cache with an empty day — a journal may
        // complete later and we want the next fetch to hit the network.
        if (cards is List && cards.isNotEmpty) {
          await _saveDailyContent(payload);
        }
        return payload;
      }
      lastFetchError = 'HTTP ${response.statusCode}';
    } catch (e) {
      lastFetchError = e.toString();
    }

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

    var dailyContent = await fetchDailyContent(forceRefresh: forceRefresh);
    final initialEmpty = dailyContent == null ||
        dailyContent['insightCards'] is! List ||
        (dailyContent['insightCards'] as List).isEmpty;
    if (initialEmpty && !forceRefresh) {
      // The local/backend cache may have been empty earlier in the day;
      // bypass it so a completed journal's insights actually load.
      dailyContent = await fetchDailyContent(forceRefresh: true);
    }

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
