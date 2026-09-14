import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/api_client.dart';
import 'crypto_service.dart';
import 'insight_service.dart';

class JournalSyncService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final String _backendUrl = AppConstants.backendUrl;
  static const String _keyPrefix = 'journal_';
  static const Duration _baseInterval = Duration(minutes: 10);
  static const Duration _maxInterval = Duration(hours: 1);

  static Timer? _syncTimer;
  static bool _syncInProgress = false;
  static Duration _currentInterval = _baseInterval;

  static void initAutoSync() {
    _scheduleNextSync();
    triggerSync();
  }

  static void triggerSync() {
    if (_syncInProgress) return;
    _syncInProgress = true;
    _syncAllLocalJournalsToCloud().then((_) {
      _currentInterval = _baseInterval;
      _syncInProgress = false;
    }).catchError((e) {
      debugPrint('[Sync] failed: $e');
      _currentInterval = Duration(
        milliseconds: (_currentInterval.inMilliseconds * 2)
            .clamp(_baseInterval.inMilliseconds, _maxInterval.inMilliseconds),
      );
      _syncInProgress = false;
    });
  }

  static void _scheduleNextSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(_currentInterval, () {
      triggerSync();
      _scheduleNextSync();
    });
  }

  static Future<bool> hasPendingSyncs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getKeys().any(
      (k) => k.startsWith(_keyPrefix) && k.endsWith('_needs_sync') && prefs.getBool(k) == true,
    );
  }

  /// Re-marks every locally stored journal for upload. Used after a Google
  /// sign-in that switched uids (anon -> existing Google account) so entries
  /// first synced under the anon uid are re-homed under the Google uid.
  /// Server upserts by id, so already-migrated rows are cheap no-ops.
  static Future<int> markAllForSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var count = 0;
      for (final key in prefs.getKeys()) {
        if (!key.startsWith(_keyPrefix) || !key.endsWith('_text')) continue;
        final stored = prefs.getString(key);
        if (stored == null || stored.trim().isEmpty) continue;
        final id = key.substring(
          _keyPrefix.length,
          key.length - '_text'.length,
        );
        if (id.isEmpty) continue;
        await prefs.setBool('$_keyPrefix${id}_needs_sync', true);
        count++;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// One awaitable sync pass. [force] bypasses the server's content-hash
  /// no-op guard so rows already stored under a previous (anon) uid are
  /// re-homed to the current uid with correct per-uid encryption.
  /// Fire-and-forget callers should keep using [triggerSync].
  static Future<void> syncNow({bool force = false}) async {
    if (_syncInProgress) return;
    _syncInProgress = true;
    try {
      await _syncAllLocalJournalsToCloud(force: force);
      _currentInterval = _baseInterval;
    } catch (e) {
      debugPrint('[Sync] failed: $e');
    } finally {
      _syncInProgress = false;
    }
  }

  static Future<void> _syncAllLocalJournalsToCloud({bool force = false}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    final List<Map<String, String>> journalsToSync = [];

    for (var key in keys) {
      if (key.startsWith(_keyPrefix) && key.endsWith('_needs_sync')) {
        if (prefs.getBool(key) == true) {
          final id = key.replaceFirst(_keyPrefix, '').replaceFirst('_needs_sync', '');
          final textKey = '$_keyPrefix${id}_text';
          final stored = prefs.getString(textKey);

          if (stored != null && stored.trim().isNotEmpty) {
            final text = await CryptoService.decrypt(stored);
            if (text.trim().isNotEmpty) {
              journalsToSync.add({'id': id, 'text': text});
            }
          }
        }
      }
    }

    if (journalsToSync.isEmpty) return;

    final syncUrl = '$_backendUrl/journals/sync';

    try {
      final response = await http
          .post(
            Uri.parse(syncUrl),
            headers: {
              'Content-Type': 'application/json',
              ...await ApiClient.authHeaders(),
            },
            body: jsonEncode({
              'uid': user.uid,
              'displayName': user.displayName,
              'email': user.email,
              'journals': journalsToSync,
              if (force) 'force': true,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 202 || response.statusCode == 200) {
        for (var journal in journalsToSync) {
          await prefs.remove('$_keyPrefix${journal['id']}_needs_sync');
        }
        await prefs.setString('last_sync_at', DateTime.now().toIso8601String());
        await InsightService.invalidateCache();
        // Queue-behind: today's served deck stays put when new journals sync —
        // fresh decks queue for following days. Only the *next*-deck prefetch
        // goes stale, so drop that; QuranPage re-prefetches in the background.
        await InsightService.invalidateNextDeckCache();
      } else {
        throw Exception('Sync failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint("Sync error: $e");
      rethrow;
    }
  }
}
