import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StarService {
  static const _totalStarsKey = 'total_stars';

  static Future<int> loadStars() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalStarsKey) ?? 0;
  }

  static Future<bool> tryIncrement(int amount, String cooldownKey) async {
    final prefs = await SharedPreferences.getInstance();
    final lastTime = prefs.getInt(cooldownKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastTime < 43200000) return false;
    await prefs.setInt(cooldownKey, now);
    final current = prefs.getInt(_totalStarsKey) ?? 0;
    await prefs.setInt(_totalStarsKey, current + amount);
    HapticFeedback.heavyImpact();
    return true;
  }

  static Future<void> forceIncrement(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_totalStarsKey) ?? 0;
    await prefs.setInt(_totalStarsKey, current + amount);
  }
}
