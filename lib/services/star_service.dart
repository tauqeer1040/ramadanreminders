import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

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

  static const _journalAwardDayKey = 'journal_award_day';

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// First journal finish of the calendar day pays. Later saves get the
  /// celebration trail with no increment. Returns true when awarded.
  static Future<bool> claimDailyJournalAward() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayKey();
      if (prefs.getString(_journalAwardDayKey) == today) return false;
      await prefs.setString(_journalAwardDayKey, today);
      return true;
    } catch (_) {
      return false;
    }
  }

  static const _firstJournalBonusKey = 'first_journal_bonus';

  /// One-time gotcha award for the very first journal ever. Local flag;
  /// the server one-timer is recorded separately via [notifyFirstJournalBonus].
  static Future<bool> claimFirstJournalBonus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_firstJournalBonusKey) ?? false) return false;
      await prefs.setBool(_firstJournalBonusKey, true);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Records the first-journal one-timer server-side. Fire-and-forget and
  /// response-ignored: the server doesn't track local-only +2s, so its
  /// total must never overwrite the local balance.
  static Future<void> notifyFirstJournalBonus() async {
    try {
      final headers = await ApiClient.postHeaders();
      await http.post(
        Uri.parse('${AppConstants.backendUrl}/stars/award'),
        headers: headers,
        body: jsonEncode({'action': 'first_journal'}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// Adds stars immediately (used per trail arrival). No cooldown here —
  /// callers gate via [claimDailyJournalAward].
  static Future<void> addStars(int amount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_totalStarsKey) ?? 0;
      await prefs.setInt(_totalStarsKey, current + amount);
    } catch (_) {}
  }

  /// +100 star Max purchase bonus, awarded once per purchase. Keyed by the
  /// same purchase key as the welcome sheet, so restores and re-opens can
  /// never double-award.
  static Future<bool> awardMaxBonus(String purchaseKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final flag = 'max_stars_awarded_$purchaseKey';
      if (prefs.getBool(flag) ?? false) return false;
      final current = prefs.getInt(_totalStarsKey) ?? 0;
      await prefs.setInt(_totalStarsKey, current + 100);
      await prefs.setBool(flag, true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
