import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bullet_item.dart';

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

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Note: Replace this with your actual local IP (e.g. 192.168.1.X) or Render URL when running on physical device
  // For Android emulator testing, use 10.0.2.2
  static const String _backendUrl = 'http://10.0.2.2:3000/api/analyze-journal';

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Saves today's journal locally to SharedPreferences for immediate persistence.
  static Future<void> saveLocalJournal(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _formatDate(DateTime.now());
    await prefs.setString('$_keyPrefix${today}_text', text);
  }

  /// Retrieves today's locally saved journal text.
  static Future<String?> getTodayLocalJournal() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _formatDate(DateTime.now());
    return prefs.getString('$_keyPrefix${today}_text');
  }

  /// Synchronizes the local journal entry for today to the Firestore cloud.
  static Future<void> syncJournalToCloud() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final today = _formatDate(DateTime.now());
    final text = await getTodayLocalJournal();
    if (text == null || text.trim().isEmpty) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('journals')
        .doc(today)
        .set({
          'text': text,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  /// Retrieves and analyzes yesterday's journal using the Node.js backend.
  static Future<Map<String, dynamic>?> getYesterdayJournalInsight() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr = _formatDate(yesterday);

    final journalRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('journals')
        .doc(dateStr);

    final docSnap = await journalRef.get();
    String text = '';

    if (docSnap.exists && docSnap.data() != null) {
      final data = docSnap.data()!;
      text = data['text'] ?? '';

      // Check Firestore cache first for existing AI analysis
      if (data.containsKey('aiAnalysis')) {
        return data['aiAnalysis'] as Map<String, dynamic>?;
      }
    } else {
      // If not in firestore, check local sharedpreferences just in case they didn't sync
      final prefs = await SharedPreferences.getInstance();
      text = prefs.getString('$_keyPrefix${dateStr}_text') ?? '';
    }

    if (text.isEmpty) return null;
    try {
      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'journalText': text}),
      );

      if (response.statusCode == 200) {
        final analysis = jsonDecode(response.body);

        // Cache the analysis in Firestore
        await journalRef.update({'aiAnalysis': analysis});

        return analysis;
      } else {
        print("Backend API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error calling backend API: $e");
      return null;
    }
  }
}
