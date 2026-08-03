import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bullet_item.dart';
import 'crypto_service.dart';
import 'streak_service.dart';

class JournalLocalStorage {
  static const String _keyPrefix = 'journal_';
  static const String _tasksKey = 'reflection_tasks';
  static const String _favoritesKey = 'favorite_journals';

  Future<void> saveGratitude(String date, String gratitude) async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = gratitude.isNotEmpty ? await CryptoService.encrypt(gratitude) : gratitude;
    await prefs.setString('$_keyPrefix${date}_gratitude', encrypted);
    StreakService.recordActivity();
  }

  Future<String> loadGratitude(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('$_keyPrefix${date}_gratitude') ?? '';
    return stored.isNotEmpty ? await CryptoService.decrypt(stored) : '';
  }

  Future<void> saveTasks(String date, List<BulletItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(tasks.map((e) => e.toJson()).toList());
    final encrypted = await CryptoService.encrypt(jsonString);
    await prefs.setString('$_keyPrefix${date}_tasks', encrypted);
  }

  Future<List<BulletItem>> loadTasks(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('$_keyPrefix${date}_tasks');
    if (stored == null) return [];
    final jsonString = await CryptoService.decrypt(stored);
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => BulletItem.fromJson(e)).toList();
  }

  Future<void> saveReflectionTasks(List<BulletItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(tasks.map((e) => e.toJson()).toList());
    await prefs.setString(_tasksKey, jsonString);
  }

  Future<List<BulletItem>> loadReflectionTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_tasksKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => BulletItem.fromJson(e)).toList();
  }

  Future<List<String>> getStoredDates() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final dates = keys
        .where((key) => key.startsWith(_keyPrefix) && key.endsWith('_gratitude'))
        .map((key) => key.replaceFirst(_keyPrefix, '').replaceFirst('_gratitude', ''))
        .toList();
    dates.sort((a, b) => b.compareTo(a));
    return dates;
  }

  static Future<void> saveText(String id, String text, {bool markForSync = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = text.isNotEmpty ? await CryptoService.encrypt(text) : text;
    await prefs.setString('$_keyPrefix${id}_text', encrypted);
    if (markForSync) {
      await prefs.setBool('$_keyPrefix${id}_needs_sync', true);
    }
  }

  static Future<String?> loadText(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('$_keyPrefix${id}_text');
    if (stored == null || stored.trim().isEmpty) return null;
    final text = await CryptoService.decrypt(stored);
    return text.trim().isEmpty ? null : text;
  }

  static Future<Map<String, String>?> loadTodayJournal(String today) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith(_keyPrefix) && key.endsWith('_text')) {
        final id = key.replaceFirst(_keyPrefix, '').replaceFirst('_text', '');
        if (id.startsWith(today)) {
          final stored = prefs.getString(key);
          if (stored != null && stored.trim().isNotEmpty) {
            final text = await CryptoService.decrypt(stored);
            if (text.trim().isNotEmpty) {
              return {'id': id, 'text': text};
            }
          }
        }
      }
    }
    return null;
  }

  static Future<List<Map<String, String>>> getAllTexts() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final List<Map<String, String>> journals = [];
    for (var key in keys) {
      if (key.startsWith(_keyPrefix) && key.endsWith('_text')) {
        final dateStr = key.replaceFirst(_keyPrefix, '').replaceFirst('_text', '');
        final stored = prefs.getString(key);
        if (stored != null && stored.trim().isNotEmpty) {
          final text = await CryptoService.decrypt(stored);
          if (text.trim().isNotEmpty) {
            journals.add({'date': dateStr, 'text': text});
          }
        }
      }
    }
    journals.sort((a, b) => b['date']!.compareTo(a['date']!));
    return journals;
  }

  static Future<void> deleteEntry(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix${id}_text');
    await prefs.remove('$_keyPrefix${id}_needs_sync');
    await prefs.remove('$_keyPrefix${id}_gratitude');
    await prefs.remove('$_keyPrefix${id}_tasks');
  }

  static Future<void> toggleFavorite(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favoritesKey) ?? [];
    if (raw.contains(date)) {
      raw.remove(date);
    } else {
      raw.add(date);
    }
    await prefs.setStringList(_favoritesKey, raw);
  }

  static Future<bool> isFavorited(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favoritesKey) ?? [];
    return raw.contains(date);
  }

  static Future<List<String>> getFavoriteDates() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  static Future<Map<String, dynamic>?> getCachedInsight(String dateStr) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedStr = prefs.getString('$_keyPrefix${dateStr}_insight');
    if (cachedStr != null) {
      try {
        final decrypted = await CryptoService.decrypt(cachedStr);
        return jsonDecode(decrypted);
      } catch (_) {}
    }
    return null;
  }

  static Future<void> cacheInsight(String dateStr, String encrypted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_keyPrefix${dateStr}_insight', encrypted);
  }
}
