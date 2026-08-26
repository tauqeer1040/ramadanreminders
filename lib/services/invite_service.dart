import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

/// Handles the "invite a friend to share your streak" feature:
/// building a personalized invite link, accepting an invite at launch,
/// and syncing each user's streak so the displayed streak is the max of
/// both friends' streaks.
class InviteService {
  static const String _inviteParam = 'invite';
  static const String _prefPendingInvite = 'pending_invite_code';
  static const String _prefLinkedFriendUid = 'friend_linked_uid';
  static const String _prefFriendName = 'friend_display_name';
  static const String _prefFriendCat = 'friend_cat_name';
  static const String _prefFriendStreak = 'friend_streak';

  static String _encode(String name, String cat, String uid) {
    final raw = '$name|$cat|$uid';
    return base64Url.encode(utf8.encode(raw));
  }

  static Map<String, String>? _decode(String code) {
    try {
      final raw = utf8.decode(base64Url.decode(code));
      final parts = raw.split('|');
      if (parts.length != 3 || parts[2].isEmpty) return null;
      return {'name': parts[0], 'cat': parts[1], 'uid': parts[2]};
    } catch (_) {
      return null;
    }
  }

  /// Build a personalized invite URL carrying the inviter's name, cat name and uid.
  static Future<String?> buildInviteUrl({String? name, String? cat}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final invName = name ?? prefs.getString('onboarding_displayName') ?? user.displayName ?? 'a friend';
    final invCat = cat ?? prefs.getString('onboarding_catName') ?? '';
    final code = _encode(invName, invCat, user.uid);
    return '${AppConstants.webAppUrl}?$_inviteParam=$code';
  }

  /// Called once at startup (after auth is established). Captures an invite
  /// from the URL on web, links the friendship on the backend, and refreshes
  /// the cached friend streak.
  static Future<void> initInvites() async {
    if (kIsWeb) {
      try {
        final code = Uri.base.queryParameters[_inviteParam];
        if (code != null && code.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefPendingInvite, code);
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_prefPendingInvite);

    if (pending != null && pending.isNotEmpty) {
      await _acceptInvite(pending);
    } else if (prefs.getString(_prefLinkedFriendUid) != null) {
      unawaited(_refreshFriendStreak());
    } else {
      // Discovery: the user may have sent an invite that someone accepted.
      // Their app never runs the accept flow, so learn the link here.
      unawaited(_discoverFriend());
    }
  }

  static Future<void> _discoverFriend() async {
    try {
      final headers = await ApiClient.authHeaders();
      final resp = await http
          .get(
            Uri.parse('${AppConstants.backendUrl}/friends/info'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body['linked'] == true) {
          final prefs = await SharedPreferences.getInstance();
          if (body['uid'] != null) {
            await prefs.setString(_prefLinkedFriendUid, body['uid']);
          }
          if (body['displayName'] != null) {
            await prefs.setString(_prefFriendName, body['displayName']);
          }
          if (body['catName'] != null) {
            await prefs.setString(_prefFriendCat, body['catName']);
          }
          unawaited(_refreshFriendStreak());
        }
      }
    } catch (_) {}
  }

  static Future<void> _acceptInvite(String code) async {
    final decoded = _decode(code);
    if (decoded == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefPendingInvite);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // retry on next launch

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_prefLinkedFriendUid) == decoded['uid']) {
      await prefs.remove(_prefPendingInvite);
      return;
    }

    try {
      final headers = await ApiClient.postHeaders();
      final myName = prefs.getString('onboarding_displayName') ?? user.displayName;
      final myCat = prefs.getString('onboarding_catName') ?? '';
      final resp = await http
          .post(
            Uri.parse('${AppConstants.backendUrl}/invites/accept'),
            headers: headers,
            body: jsonEncode({
              'inviterUid': decoded['uid'],
              'myName': myName,
              'myCat': myCat,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        await prefs.setString(_prefLinkedFriendUid, decoded['uid']!);
        final inviter = body['inviter'];
        if (inviter != null) {
          if (inviter['displayName'] != null) {
            await prefs.setString(_prefFriendName, inviter['displayName']);
          }
          if (inviter['catName'] != null) {
            await prefs.setString(_prefFriendCat, inviter['catName']);
          }
        }
        await prefs.remove(_prefPendingInvite);
        await _refreshFriendStreak();
      }
    } catch (e) {
      debugPrint('[InviteService] accept invite error: $e');
    }
  }

  /// Push the local streak to the server so the friend can read it.
  static Future<void> pushMyStreak(int streak) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final headers = await ApiClient.postHeaders();
      unawaited(
        http
            .post(
              Uri.parse('${AppConstants.backendUrl}/streaks/sync'),
              headers: headers,
              body: jsonEncode({'streak': streak}),
            )
            .timeout(const Duration(seconds: 10))
            .then((_) => _refreshFriendStreak())
            .catchError((_) {}),
      );
    } catch (e) {
      debugPrint('[InviteService] pushMyStreak error: $e');
    }
  }

  static Future<void> _refreshFriendStreak() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_prefLinkedFriendUid) == null) return;
    try {
      final headers = await ApiClient.authHeaders();
      final resp = await http
          .get(
            Uri.parse('${AppConstants.backendUrl}/streaks/friend'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        if (body['linked'] == true && body['streak'] != null) {
          await prefs.setInt(_prefFriendStreak, body['streak'] as int);
        }
      }
    } catch (_) {}
  }

  /// Cached friend streak (0 when not linked or not yet loaded).
  static Future<int> getFriendStreakCached() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefFriendStreak) ?? 0;
  }

  static Future<bool> isFriendLinked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefLinkedFriendUid) != null;
  }

  static Future<String?> getFriendName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefFriendName);
  }

  static Future<String?> getFriendCat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefFriendCat);
  }

  /// Human-readable label for the friend, e.g. "Whiskers (John)".
  static Future<String?> getFriendLabel() async {
    final name = await getFriendName();
    final cat = await getFriendCat();
    if (name == null && cat == null) return null;
    if (cat != null && cat.isNotEmpty) {
      return name != null && name.isNotEmpty ? '$cat ($name)' : cat;
    }
    return name;
  }
}
