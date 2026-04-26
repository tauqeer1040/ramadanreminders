import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/bullet_item.dart';
import 'insight_service.dart';

class JournalService {
  static const String _keyPrefix = 'journal_';
  static const String _tasksKey = 'reflection_tasks';

  // Save journal entry (gratitude) for a specific date
  Future<void> saveJournalGratitude(String date, String gratitude) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix${date}_gratitude', gratitude);
  }

  // Load journal entry (gratitude) for a specific date
  Future<String> loadJournalGratitude(String date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_keyPrefix${date}_gratitude') ?? '';
  }

  // Save journal tasks for a specific date
  Future<void> saveJournalTasks(String date, List<BulletItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await prefs.setString('$_keyPrefix${date}_tasks', jsonString);
  }

  // Load journal tasks for a specific date
  Future<List<BulletItem>> loadJournalTasks(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString('$_keyPrefix${date}_tasks');
    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => BulletItem.fromJson(e)).toList();
  }

  // Save a list of generic reflection tasks (not date specific if needed)
  Future<void> saveReflectionTasks(List<BulletItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await prefs.setString(_tasksKey, jsonString);
  }

  // Load generic reflection tasks
  Future<List<BulletItem>> loadReflectionTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_tasksKey);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => BulletItem.fromJson(e)).toList();
  }

  // Get all dates that have journal entries
  Future<List<String>> getStoredDates() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    // Filter keys that end with _gratitude to identify valid dates
    final dates = keys
        .where(
          (key) => key.startsWith(_keyPrefix) && key.endsWith('_gratitude'),
        )
        .map(
          (key) =>
              key.replaceFirst(_keyPrefix, '').replaceFirst('_gratitude', ''),
        )
        .toList();

    // Sort by date descending (newest first)
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  // --- NEW AI JOURNAL FEATURE CAPABILITIES ---

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Note: Replace this with your actual local IP (e.g. 192.168.1.X) or Render URL when running on physical device
  // For Android emulator testing, use 10.0.2.2
  // V2 Turso Backend URL
  static final String _backendUrl = AppConstants.backendUrl;

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _difficultyForIndex(int index) {
    if (index == 0) return 'easy';
    if (index == 1) return 'mid';
    return 'hard';
  }

  /// Formats a "YYYY-MM-DD" string into "16th March 2026"
  static String formatDisplayDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dateOnly = dateStr.contains('T') ? dateStr.split('T')[0] : dateStr;
      final parts = dateOnly.split('-');
      if (parts.length != 3) return dateStr;

      final int year = int.parse(parts[0]);
      final int month = int.parse(parts[1]);
      final int day = int.parse(parts[2]);

      final months = [
        "", "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
      ];

      String suffix = 'th';
      if (day == 1 || day == 21 || day == 31) suffix = 'st';
      else if (day == 2 || day == 22) suffix = 'nd';
      else if (day == 3 || day == 23) suffix = 'rd';

      final safeMonth = (month >= 1 && month <= 12) ? months[month] : '';
      return '${day}$suffix $safeMonth $year';
    } catch (_) {
      return dateStr;
    }
  }

  /// Checks if the user is anonymous and has already used all 3 free trial journals
  static Future<bool> isGuestLimitReached() async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) return false;

    final existing = await getAllLocalJournals();
    final today = _formatDate(DateTime.now());
    final hasToday = existing.any((j) => j['date'] == today);
    
    // Limits the user to strictly 3 days of journaling before requiring an account
    return !hasToday && existing.length >= 3;
  }

  /// Saves a journal locally to SharedPreferences for immediate persistence over a unique ID.
  static Future<void> saveLocalJournalWithId(String id, String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix${id}_text', text);
    
    // Explicitly flag this precise ID as fundamentally modified allowing the sync engine to identify it
    await prefs.setBool('$_keyPrefix${id}_needs_sync', true);
  }

  /// Retrieves all locally saved journals as a list of maps {date, text}
  static Future<List<Map<String, String>>> getAllLocalJournals() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    final List<Map<String, String>> journals = [];

    for (var key in keys) {
      if (key.startsWith(_keyPrefix) && key.endsWith('_text')) {
        final dateStr = key
            .replaceFirst(_keyPrefix, '')
            .replaceFirst('_text', '');
        final text = prefs.getString(key);
        if (text != null && text.trim().isNotEmpty) {
          journals.add({'date': dateStr, 'text': text});
        }
      }
    }

    // Sort by date descending (newest first)
    journals.sort((a, b) => b['date']!.compareTo(a['date']!));
    return journals;
  }

  static Timer? _syncTimer;

  static void initAutoSync() {
    // Non-blocking fire-and-forget sync on launch
    Future.microtask(() async {
      await syncAllLocalJournalsToCloud();
      await InsightService.fetchDailyContent(forceRefresh: true);
    });
    _scheduleNextMidnightSync();
  }

  static void _scheduleNextMidnightSync() {
    final now = DateTime.now();
    // Midnight tonight
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final durationToMidnight = nextMidnight.difference(now);

    _syncTimer?.cancel();
    _syncTimer = Timer(durationToMidnight, () {
      // Execute the sync exactly at midnight
      syncAllLocalJournalsToCloud();
      // Schedule the next midnight sync recursively
      _scheduleNextMidnightSync();
    });
  }

  /// Syncs exclusively modified local journals purely over HTTP POST to the V2 backend
  static Future<void> syncAllLocalJournalsToCloud() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    final List<Map<String, String>> journalsToSync = [];

    for (var key in keys) {
      if (key.startsWith(_keyPrefix) && key.endsWith('_needs_sync')) {
        if (prefs.getBool(key) == true) {
          final id = key.replaceFirst(_keyPrefix, '').replaceFirst('_needs_sync', '');
          final textKey = '$_keyPrefix${id}_text';
          final text = prefs.getString(textKey);

          if (text != null && text.trim().isNotEmpty) {
            journalsToSync.add({'id': id, 'text': text});
          }
        }
      }
    }

    if (journalsToSync.isEmpty) return;

    final syncUrl = '$_backendUrl/journals/sync';

    try {
      final response = await http
          .post(
            Uri.parse(syncUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'uid': user.uid,
              'displayName': user.displayName,
              'email': user.email,
              'journals': journalsToSync,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 202 || response.statusCode == 200) {
        for (var journal in journalsToSync) {
          await prefs.remove('$_keyPrefix${journal['id']}_needs_sync');
        }
        await InsightService.invalidateCache();
      } else {
        throw Exception('Sync failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print("Sync error: $e");
      rethrow;
    }
  }

  /// Fetches the latest stored AI tasks for a user from the V2 backend and caches them locally.
  Future<List<BulletItem>> fetchLatestAIDrivenTasks(String uid) async {
    try {
      final payload = await InsightService.fetchDailyContent();
      final List<dynamic> tasksRaw = payload?['tasks'] is List ? payload!['tasks'] as List<dynamic> : const [];

      if (tasksRaw.isNotEmpty) {
        final tasks = tasksRaw.asMap().entries.map((entry) {
          final idx = entry.key;
          final task = Map<String, dynamic>.from(entry.value as Map);
          return BulletItem(
            id: (task['id'] ?? 'ai_task_$idx').toString(),
            content: (task['content'] ?? 'Ramadan Task').toString(),
            difficulty: (task['difficulty'] ?? _difficultyForIndex(idx)).toString(),
          );
        }).toList();

        final today = _formatDate(DateTime.now());
        await saveJournalTasks(today, tasks);
        return tasks;
      }
    } catch (e) {
      print("Error fetching AI tasks: $e");
    }
    return [];
  }

  /// Retrieves yesterday's AI insight strictly from SharedPreferences cache.
  static Future<Map<String, dynamic>?> getLocalYesterdayJournalInsight() async {
    final prefs = await SharedPreferences.getInstance();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = _formatDate(yesterday);
    final cachedStr = prefs.getString('$_keyPrefix${dateStr}_insight');
    if (cachedStr != null) {
      try {
        return jsonDecode(cachedStr);
      } catch (_) {}
    }
    return null;
  }

  /// Retrieves yesterday's stored insight from the V2 backend.
  /// The backend owns generation and persistence; the client only reads rows.
  static Future<Map<String, dynamic>?> getYesterdayJournalInsight() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = _formatDate(yesterday);
    
    // First check local preferences directly
    final prefs = await SharedPreferences.getInstance();
    final cachedStr = prefs.getString('$_keyPrefix${dateStr}_insight');
    if (cachedStr != null) {
      try {
        return jsonDecode(cachedStr);
      } catch (_) {}
    }
    
    // Read the user's journal feed from the backend and pick yesterday's row.
    try {
      final response = await http
          .get(Uri.parse('$_backendUrl/user/${user.uid}/journals'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> journals = jsonDecode(response.body);
        final match = journals.cast<Map<String, dynamic>?>().firstWhere(
          (journal) {
            if (journal == null) return false;
            final createdAt = (journal['createdAt'] ?? '').toString();
            return createdAt.startsWith(dateStr) && journal['summary'] != null;
          },
          orElse: () => null,
        );

        if (match != null) {
          final analysis = <String, dynamic>{
            'summary': match['summary'],
            'tags': match['tags'] ?? [],
            'quote': match['quote'],
            'reference': match['reference'],
            'suggestedTasks': match['suggestedTasks'] ?? [],
            'taskTags': match['taskTags'] ?? [],
            'status': match['status'],
            'createdAt': match['createdAt'],
          };
          await prefs.setString('$_keyPrefix${dateStr}_insight', jsonEncode(analysis));
          return analysis;
        }
      }
    } catch (e) {
      print('Error fetching yesterday insight: $e');
    }

    return null;
  }
}
