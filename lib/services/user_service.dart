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
      final streak = prefs.getInt('streak');
      final streakDate = prefs.getString('last_activity_date');
      final headers = await ApiClient.postHeaders();
      final res = await http
          .post(
            Uri.parse('${AppConstants.backendUrl}/user/state'),
            headers: headers,
            body: jsonEncode({
              'stars': stars,
              'purchases': purchases,
              if (shields != null) 'shieldBalance': shields,
              if (streak != null) 'streak': streak,
              if (streakDate != null) 'streakDate': streakDate,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        // Adopt the server's post-merge verdict: when this device's clock
        // was behind, the echo carries the authoritative streak/date.
        try {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          final srvStreak = body['streak'];
          final srvDate = body['streakDate'];
          if (srvStreak is num && srvDate is String && srvDate.isNotEmpty) {
            final localDate = prefs.getString('last_activity_date');
            if (localDate == null || srvDate.compareTo(localDate) >= 0) {
              if (srvStreak.toInt() > (prefs.getInt('streak') ?? 0)) {
                await prefs.setInt('streak', srvStreak.toInt());
              }
              if (srvDate != localDate) {
                await prefs.setString('last_activity_date', srvDate);
              }
            }
          }
        } catch (_) {}
        return true;
      }
      return false;
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

      // Journal-date history backfill first (activity-dates graph, max-wins
      // count), then the DB streak — users.streak is authoritative for the
      // number and lands last so neither pass can mask a server-side edit.
      await _restoreStreakFromServer(headers, prefs);
      final srvStreak = body['streak'];
      if (srvStreak is num && srvStreak > 0) {
        final adopted = await _adoptServerStreak(
          prefs,
          srvStreak.toInt(),
          body['streak_date'] as String?,
        );
        if (adopted) {
          debugPrint('[UserService] Adopted server streak: ${srvStreak.toInt()}');
        }
      }

      return true;
    } catch (e) {
      debugPrint('[UserService] restoreProfile failed: $e');
      return false;
    }
  }

  /// Adopts the server's streak into local prefs. The DB value wins when its
  /// observation is at least as fresh as local (missing streak_date is
  /// treated as "current today"); a strictly older server observation is
  /// rejected so an offline device's newer local run is never rolled back.
  static Future<bool> _adoptServerStreak(
    SharedPreferences prefs,
    int streak,
    String? serverDate,
  ) async {
    final now = DateTime.now();
    final today =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final effective =
        (serverDate == null || serverDate.isEmpty) ? today : serverDate;
    final localDate = prefs.getString('last_activity_date');
    if (localDate != null && effective.compareTo(localDate) < 0) {
      return false; // server older than local -> keep local
    }
    await prefs.setInt('streak', streak);
    await prefs.setString('last_activity_date', effective);
    return true;
  }

  /// Launch-time streak pull (users.streak is the primary store). When the
  /// server responds, its value is adopted so DB-side edits and cross-device
  /// moves show up locally. If the server does NOT respond — offline,
  /// timeout, non-200, bad payload — the local streak is kept untouched
  /// (fail-open). Never throws.
  static Future<bool> pullStreakFromServer() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return false;
      final headers = await ApiClient.authHeaders();
      final res = await http
          .get(
            Uri.parse('${AppConstants.backendUrl}/user/$uid/streak'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) {
        debugPrint('[UserService] streak pull: HTTP ${res.statusCode}, keeping local');
        return false;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final streak = (body['streak'] as num?)?.toInt() ?? 0;
      if (streak <= 0) return false; // no usable server value -> keep local
      final prefs = await SharedPreferences.getInstance();
      final adopted = await _adoptServerStreak(
        prefs,
        streak,
        body['streakDate'] as String?,
      );
      if (adopted) {
        debugPrint('[UserService] Pulled streak from server: $streak');
      }
      return adopted;
    } catch (e) {
      debugPrint('[UserService] streak pull failed (keeping local): $e');
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

      // Merge server-known active days with the device's own history BEFORE
      // recomputing: the fetch is capped at 50 entries, so a long journal
      // history can lack the most recent days entirely. Recomputing from the
      // raw server page alone produced a stale/zero streak and — worse — a
      // stale last_activity_date, which the next launch read as a >1-day gap
      // and reset the streak to 1 (the reported sync bug).
      final localDates =
          prefs.getStringList('streak_activity_dates') ?? const <String>[];
      final mergedDays = <String>{...days, ...localDates}.toList()
        ..sort();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      var cursor = mergedDays.contains(fmt(today))
          ? today
          : today.subtract(const Duration(days: 1));
      var streak = 0;
      while (mergedDays.contains(fmt(cursor))) {
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
        await prefs.setStringList('streak_activity_dates', mergedDays);
        // Only ADVANCE last_activity_date — never overwrite it with an older
        // observation. The old unconditional write is what corrupted gap
        // detection and reset streaks on launch.
        final curLast = prefs.getString('last_activity_date');
        final newest = mergedDays.last;
        if (curLast == null || newest.compareTo(curLast) > 0) {
          await prefs.setString('last_activity_date', newest);
        }
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
