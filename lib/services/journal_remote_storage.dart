import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/api_client.dart';
import '../models/bullet_item.dart';
import 'crypto_service.dart';
import 'insight_service.dart';
import 'journal_local_storage.dart';

class JournalRemoteStorage {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final String _backendUrl = AppConstants.backendUrl;

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _difficultyForIndex(int index) {
    if (index == 0) return 'easy';
    if (index == 1) return 'mid';
    return 'hard';
  }

  Future<List<BulletItem>> fetchLatestTasks(String uid) async {
    try {
      final payload = await InsightService.fetchDailyContent();
      final List<dynamic> tasksRaw = payload?['tasks'] is List ? payload!['tasks'] as List<dynamic> : [];
      if (tasksRaw.isNotEmpty) {
        final tasks = tasksRaw.asMap().entries.map((entry) {
          final idx = entry.key;
          final task = Map<String, dynamic>.from(entry.value as Map);
          return BulletItem(
            id: (task['id'] ?? 'ai_task_$idx').toString(),
            content: (task['content'] ?? 'Daily Task').toString(),
            difficulty: (task['difficulty'] ?? _difficultyForIndex(idx)).toString(),
          );
        }).toList();
        final today = _formatDate(DateTime.now());
        await JournalLocalStorage().saveTasks(today, tasks);
        return tasks;
      }
    } catch (e) {
      print("Error fetching AI tasks: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> getYesterdayInsight() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = _formatDate(yesterday);

    final cached = await JournalLocalStorage.getCachedInsight(dateStr);
    if (cached != null) return cached;

    try {
      final response = await http
          .get(
            Uri.parse('$_backendUrl/user/${user.uid}/journals'),
            headers: await ApiClient.authHeaders(),
          )
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
          final encrypted = await CryptoService.encrypt(jsonEncode(analysis));
          await JournalLocalStorage.cacheInsight(dateStr, encrypted);
          return analysis;
        }
      }
    } catch (e) {
      print('Error fetching yesterday insight: $e');
    }

    return null;
  }

  /// Pulls the signed-in user's remote journals into local storage so past
  /// entries and stats appear immediately after sign-in. Skips any id already
  /// present locally. Returns the number of entries merged.
  static Future<int> pullAllJournalsToLocal() async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return 0;

    try {
      final response = await http
          .get(
            Uri.parse('$_backendUrl/user/${user.uid}/journals'),
            headers: await ApiClient.authHeaders(),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return 0;

      final List<dynamic> journals = jsonDecode(response.body);
      int merged = 0;
      for (final raw in journals) {
        if (raw is! Map<String, dynamic>) continue;
        final id = (raw['id'] ?? '').toString().trim();
        final text = (raw['content'] ?? '').toString().trim();
        if (id.isEmpty || text.isEmpty) continue;
        final existing = await JournalLocalStorage.loadText(id);
        if (existing != null && existing.trim().isNotEmpty) continue;
        await JournalLocalStorage.saveText(id, text, markForSync: false);
        merged++;
      }
      return merged;
    } catch (e) {
      print('Error pulling journals to local: $e');
      return 0;
    }
  }
}
