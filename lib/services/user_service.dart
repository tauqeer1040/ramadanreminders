import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

class UserService {
  static Future<void> syncUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final catName = prefs.getString('onboarding_catName');
      final headers = await ApiClient.postHeaders();
      await http.post(
        Uri.parse('${AppConstants.backendUrl}/user/upsert'),
        headers: headers,
        body: jsonEncode({
          'displayName': user.displayName,
          'email': user.email,
          'catName': catName,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[UserService] syncUser error: $e');
    }
  }

  /// Pushes device-local progress to the server so a later reinstall or new
  /// device can restore it. Merge semantics only, never overwrite-down:
  /// stars and shield balance resolve to max(server, local), shop unlocks
  /// union. Best-effort — returns true when the server accepted the merge.
  /// Never throws.
  static Future<bool> pushLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stars = prefs.getInt('total_stars') ?? 0;
      final raw = prefs.getString('shop_unlocked');
      List<String> purchases = const [];
      if (raw != null && raw.isNotEmpty) {
        try {
          purchases =
              (jsonDecode(raw) as List).whereType<String>().toList();
        } catch (_) {}
      }
      final shields = prefs.getInt('shield_balance');
      final headers = await ApiClient.postHeaders();
      final res = await http
          .post(
            Uri.parse('${AppConstants.backendUrl}/user/state'),
            headers: headers,
            body: jsonEncode({
              'stars': stars,
              'purchases': purchases,
              if (shields != null) 'shieldBalance': shields,
            }),
          )
          .timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[UserService] pushLocalState failed: $e');
      return false;
    }
  }

  /// Pulls the server profile + wallet into local prefs for returning
  /// users (new device, reinstall, or skipped onboarding + sign-in).
  /// Restores: display/cat names (notification copy reads these), email,
  /// stars (max of server/local so local-only awards are never wiped),
  /// shop unlocks (union), shields (max, same reason), and streak (max of
  /// local vs recomputed-from-server-journals — a sign-in must never shrink
  /// a healthy local streak). Quran revealed ids pull separately via
  /// [InsightService.pullRevealedFromServer] (server holds reveal acks).
  /// Returns true on success. Never throws.
  static Future<bool> restoreProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final headers = await ApiClient.authHeaders();
      final res = await http.get(
        Uri.parse('${AppConstants.backendUrl}/user/$uid'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      final displayName = (body['display_name'] as String?)?.trim() ?? '';
      if (displayName.isNotEmpty) {
        await prefs.setString('onboarding_displayName', displayName);
      }
      final catName = (body['cat_name'] as String?)?.trim() ?? '';
      if (catName.isNotEmpty) {
        await prefs.setString('onboarding_catName', catName);
      }
      final email = (body['email'] as String?)?.trim() ?? '';
      if (email.isNotEmpty) {
        await prefs.setString('onboarding_email', email);
      }

      final serverStars = (body['stars'] as num?)?.toInt();
      if (serverStars != null) {
        final localStars = prefs.getInt('total_stars') ?? 0;
        if (serverStars > localStars) {
          await prefs.setInt('total_stars', serverStars);
        }
      }

      final purchases = body['purchases'];
      final rawPurchases = purchases is List
          ? purchases
          : (purchases is String && purchases.isNotEmpty
              ? jsonDecode(purchases)
              : null);
      if (rawPurchases is List) {
        try {
          final ids =
              rawPurchases.whereType<String>().toSet();
          if (ids.isNotEmpty) {
            final raw = prefs.getString('shop_unlocked');
            final unlocked = raw != null
                ? Set<String>.from(jsonDecode(raw) as List)
                : <String>{};
            final before = unlocked.length;
            unlocked.addAll(ids);
            if (unlocked.length != before) {
              await prefs.setString(
                  'shop_unlocked', jsonEncode(unlocked.toList()));
            }
          }
        } catch (_) {}
      }

      final shields = (body['shield_balance'] as num?)?.toInt();
      if (shields != null) {
        // Max, not overwrite: anon-earned shields must survive signing into
        // an older/existing Google row that reports a smaller balance.
        final localShields = prefs.getInt('shield_balance') ?? 0;
        if (shields > localShields) {
          await prefs.setInt('shield_balance', shields);
        }
      }

      await _restoreStreakFromServer(headers, prefs);
      return true;
    } catch (e) {
      debugPrint('[UserService] restoreProfile failed: $e');
      return false;
    }
  }

  /// Recomputes streak + activity dates from server journal dates.
  /// Leaves local streak untouched when the fetch yields nothing AND never
  /// shrinks a healthy local streak (max wins — sign-in must not wipe it).
  static Future<void> _restoreStreakFromServer(
    Map<String, String> headers,
    SharedPreferences prefs,
  ) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final res = await http.get(
        Uri.parse('${AppConstants.backendUrl}/user/$uid/journals?limit=50'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      final entries = body is List
          ? body
          : (body is Map<String, dynamic> ? body['journals'] : null);
      if (entries is! List || entries.isEmpty) return;

      final days = <String>{};
      for (final e in entries) {
        if (e is! Map) continue;
        final raw = e['createdAt'] ?? e['created_at'];
        if (raw is! String || raw.isEmpty) continue;
        final dt = DateTime.tryParse(raw);
        if (dt == null) continue;
        final local = dt.toLocal();
        days.add(
            '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}');
      }
      if (days.isEmpty) return;

      final now = DateTime.now();
      final today =
          DateTime(now.year, now.month, now.day);
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      var cursor =
          days.contains(fmt(today)) ? today : today.subtract(const Duration(days: 1));
      var streak = 0;
      while (days.contains(fmt(cursor))) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      if (streak > 0) {
        // Max wins: a Google row with fewer journals must never shrink the
        // local streak (the reported "sign-in wiped my streak" bug).
        final localStreak = prefs.getInt('streak') ?? 1;
        if (streak > localStreak) {
          await prefs.setInt('streak', streak);
        }
        final sorted = days.toList()..sort();
        final localDates =
            prefs.getStringList('streak_activity_dates') ?? const [];
        final merged = {...localDates, ...sorted}.toList()..sort();
        await prefs.setStringList('streak_activity_dates', merged);
        await prefs.setString(
            'last_activity_date', merged.last);
      }
    } catch (_) {}
  }

  /// Saves an email address without touching other profile fields
  /// (backend COALESCEs nulls). Used by the Max welcome sheet so the
  /// value-recap email has somewhere to go for anonymous users.
  static Future<void> updateEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      throw ArgumentError('Invalid email');
    }
    try {
      final headers = await ApiClient.postHeaders();
      final response = await http.post(
        Uri.parse('${AppConstants.backendUrl}/user/upsert'),
        headers: headers,
        body: jsonEncode({'email': trimmed}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw StateError('Email save failed: ${response.statusCode}');
      }
      // An address may have arrived after purchase (welcome sheet): trigger
      // the value-recap email now. Best-effort — the sheet already confirmed.
      try {
        await http.post(
          Uri.parse('${AppConstants.backendUrl}/subscription/recap-email'),
          headers: headers,
          body: jsonEncode({}),
        ).timeout(const Duration(seconds: 10));
      } catch (_) {}
    } catch (e) {
      debugPrint('[UserService] updateEmail error: $e');
      rethrow;
    }
  }

  static Future<void> deleteUserAccount(User user) async {
    try {
      await user.delete();
    } catch (e) {
      debugPrint("User deletion error: $e");
      rethrow;
    }
  }
}
