import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import 'insight_service.dart' show InsightCard, DeckResult;

/// Client-side insight rotation.
///
/// Model (product decision):
///   * The device caches ALL the user's AI decks once (server `/decks/all`,
///     newest journal first) and rotates locally — the server is only the
///     source of truth for content, never for daily serving state.
///   * Every launch shows a different deck of 3 insights, newest-first,
///     looping back to the start after the list is exhausted.
///   * Max 3 deck *changes* per local day; after that, launches cycle among
///     the 3 decks already shown today.
///   * Decks the user is mid-reveal are protected (not rotated away) until
///     fully revealed.
///
/// Storage is a single JSON blob in SharedPreferences, written atomically.
class DeckRotationService {
  DeckRotationService._();

  static const _storageKey = 'deck_rotation_state_v1';
  static const int decksPerDay = 3;

  // ── State shape ──
  // {
  //   'syncedAt': iso8601,          // last successful /decks/all sync
  //   'decks': [deckPayload, ...],  // newest-first cached server decks
  //   'cursor': int,                // absolute position in the deck list
  //   'day': 'yyyy-MM-dd',          // local day of the change counter
  //   'changesToday': int,          // deck changes consumed today (0..3)
  //   'todayDeckIds': [id, id, id], // decks shown today (for cycling)
  //   'currentDeckId': id|null,     // deck currently on screen
  // }
  static Map<String, dynamic>? _state;
  static bool _loaded = false;

  static Future<Map<String, dynamic>> _load() async {
    if (_loaded && _state != null) return _state!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        _state = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } catch (_) {}
    _state ??= <String, dynamic>{};
    _loaded = true;
    return _state!;
  }

  static Future<void> _save(Map<String, dynamic> state) async {
    _state = state;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state));
    } catch (e) {
      debugPrint('[DeckRotation] save failed: $e');
    }
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  // ── Sync ──

  /// Pull all decks from the server into the local cache. Called on app
  /// boot (fire-and-forget) and after a new journal completes. Never
  /// advances the cursor — new decks arrive at the FRONT of the list (they
  /// are newest), which is exactly where a fresh launch should pick up.
  static Future<bool> sync() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      // Non-Android falls through to legacy paths; nothing to do here.
      return false;
    }
    final user = FirebaseAuth.instance.currentUser?.uid;
    if (user == null) return false;
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.backendUrl}/user/$user/decks/all'),
        headers: await ApiClient.authHeaders(),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        debugPrint('[DeckRotation] sync HTTP ${response.statusCode}');
        return false;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final list = (payload['decks'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((p) {
            final cards = p['insightCards'];
            return p['deckId'] is String &&
                (p['deckId'] as String).startsWith('deck_') &&
                cards is List &&
                cards.isNotEmpty;
          })
          .toList();
      final state = await _load();
      // Keep decks the server no longer returns (edge: journal deleted but
      // its deck rows are gone) so the user never loses cached content
      // mid-cycle. New decks land at the front automatically (server order).
      final serverIds = list.map((p) => p['deckId'] as String).toSet();
      final extras = (state['decks'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where((p) => !serverIds.contains(p['deckId']))
          .toList();
      state['decks'] = [...list, ...extras];
      state['syncedAt'] = DateTime.now().toIso8601String();
      await _save(state);
      return true;
    } catch (e) {
      debugPrint('[DeckRotation] sync failed: $e');
      return false;
    }
  }

  // ── Day bookkeeping ──

  static Map<String, dynamic> _rollDayIfNeeded(Map<String, dynamic> state) {
    final today = _today();
    if (state['day'] != today) {
      state['day'] = today;
      state['changesToday'] = 0;
      state['todayDeckIds'] = <String>[];
    }
    return state;
  }

  // ── Rotation ──

  /// Deck to show right now.
  ///
  ///  * Current deck protected (user mid-reveal): returns it unchanged
  ///    (no cap consumed).
  ///  * First paint of the day: advances to the next unseen deck (change 1
  ///    of 3), unless the app was reopened on the same deck without reveals.
  ///  * Cap consumed: cycles among today's shown decks, in order.
  ///  * Empty cache: returns null (caller falls back to verse decks).
  ///
  /// [revealedCardIds] and [currentCards] describe what's on screen.
  static Future<DeckResult?> currentDeckForLaunch({
    required Set<String> revealedCardIds,
    required List<InsightCard> currentCards,
    String? currentDeckId,
    bool fullyRevealed = false,
  }) async {
    final state = _rollDayIfNeeded(await _load());
    final decks = (state['decks'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    // Protected: user is mid-reveal (started but not finished) on a real
    // deck — rotation never yanks it.
    final curId = currentDeckId;
    final hasContent = currentCards.isNotEmpty;
    final anyRevealed = revealedCardIds.isNotEmpty && !fullyRevealed;
    if (hasContent &&
        anyRevealed &&
        curId != null &&
        curId.startsWith('deck_') &&
        decks.any((d) => d['deckId'] == curId)) {
      return _result(decks.firstWhere((d) => d['deckId'] == curId));
    }

    int cursor = (state['cursor'] as int?) ?? 0;
    if (decks.isEmpty) return null;

    final changesToday = (state['changesToday'] as int?) ?? 0;

    // Same-deck relaunch: no reveals since last time → don't burn a change.
    if (hasContent &&
        !anyRevealed &&
        curId != null &&
        state['currentDeckId'] == curId &&
        changesToday > 0) {
      return _result(decks.firstWhere((d) => d['deckId'] == curId));
    }

    if (changesToday >= decksPerDay) {
      // Cap consumed: cycle among the decks already shown today.
      final todayIds = (state['todayDeckIds'] as List? ?? [])
          .map((e) => e as String)
          .toList();
      if (todayIds.isNotEmpty) {
        // Next deck in today's order, wrapping; keeps launches "different"
        // without consuming anything new.
        final idx = todayIds.indexOf(curId ?? '');
        final nextId = todayIds[(idx < 0 ? 0 : idx + 1) % todayIds.length];
        final payload = decks.firstWhere(
          (d) => d['deckId'] == nextId,
          orElse: () => decks.first,
        );
        state['currentDeckId'] = payload['deckId'];
        await _save(state);
        return _result(payload);
      }
    }

    // Normal advance: cursor forward one deck, loop the list.
    // When the cache was refilled (new decks at the front), the cursor
    // naturally lands on fresh content first — newest-first order.
    cursor = cursor % decks.length;
    var payload = decks[cursor];
    // Never show the same deck twice in a row across a change.
    if (payload['deckId'] == curId && decks.length > 1) {
      cursor = (cursor + 1) % decks.length;
      payload = decks[cursor];
    }
    state['cursor'] = (cursor + 1) % decks.length;
    state['changesToday'] = changesToday + 1;
    final todayIds = (state['todayDeckIds'] as List? ?? [])
        .map((e) => e as String)
        .toList();
    if (!todayIds.contains(payload['deckId'])) {
      todayIds.add(payload['deckId'] as String);
    }
    // Keep at most the last decksPerDay ids (cycling window).
    while (todayIds.length > decksPerDay) {
      todayIds.removeAt(0);
    }
    state['todayDeckIds'] = todayIds;
    state['currentDeckId'] = payload['deckId'];
    await _save(state);
    return _result(payload);
  }

  /// Mark the on-screen deck (syncs bookkeeping when the UI adopts a deck
  /// through another path, e.g. first-launch legacy paint).
  static Future<void> noteCurrentDeck(String deckId) async {
    final state = _rollDayIfNeeded(await _load());
    if (state['currentDeckId'] == deckId) return;
    state['currentDeckId'] = deckId;
    await _save(state);
  }

  static DeckResult _result(Map<String, dynamic> payload) {
    final cards = (payload['insightCards'] as List? ?? [])
        .map((e) => InsightCard.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((c) => c.type.isNotEmpty)
        .toList();
    return DeckResult(
      deckId: payload['deckId'] as String?,
      journalId: payload['journalId'] as String?,
      cards: cards,
      queueDepth: 0,
      fallback: false,
    );
  }

  /// Debug/ops peek.
  static Future<Map<String, dynamic>> debugState() async => _load();
}
