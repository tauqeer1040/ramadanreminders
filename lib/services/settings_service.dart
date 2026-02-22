import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _hijriAdjustmentKey = 'hijri_adjustment';

  // Save Hijri adjustment (e.g., +1, -1, 0)
  Future<void> saveHijriAdjustment(int adjustment) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hijriAdjustmentKey, adjustment);
  }

  // Load Hijri adjustment, default to 0
  Future<int> loadHijriAdjustment() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_hijriAdjustmentKey) ?? 0;
  }
}
