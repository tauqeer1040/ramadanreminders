import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/tasbih/model/dhikr_item.dart';

class DhikrService {
  static const String _dhikrKey = 'custom_dhikr_list';
  static const String _totalCountKey = 'total_dhikr_count';

  Future<void> saveDhikrs(List<DhikrItem> dhikrs) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(
      dhikrs.map((d) => d.toJson()).toList(),
    );
    await prefs.setString(_dhikrKey, jsonString);
  }

  Future<List<DhikrItem>?> loadDhikrs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_dhikrKey);
    if (jsonString == null) return null;

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((e) => DhikrItem.fromJson(e)).toList();
    } catch (e) {
      return null;
    }
  }

  Future<void> saveTotalDhikrCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_totalCountKey, count);
  }

  Future<int> loadTotalDhikrCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalCountKey) ?? 0;
  }
}
