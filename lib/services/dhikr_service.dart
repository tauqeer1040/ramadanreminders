import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/tesbihpage.dart' show DhikrItem;

class DhikrService {
  static const String _dhikrKey = 'custom_dhikr_list';

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
}
