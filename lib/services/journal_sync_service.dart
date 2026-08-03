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

  static Future<void> _syncAllLocalJournalsToCloud() async {
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
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 202 || response.statusCode == 200) {
        for (var journal in journalsToSync) {
          await prefs.remove('$_keyPrefix${journal['id']}_needs_sync');
        }
        await prefs.setString('last_sync_at', DateTime.now().toIso8601String());
        await InsightService.invalidateCache();
      } else {
        throw Exception('Sync failed with status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint("Sync error: $e");
      rethrow;
    }
  }
}
