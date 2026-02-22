import 'dart:convert';
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
}
