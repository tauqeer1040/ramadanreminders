import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import 'deck_queue_logic.dart' show isDeckFullyRevealed;
import 'insight_service.dart' show InsightCard, DeckResult;

/// Client-side insight rotation.
///
/// Model (product decision):
///   * The device caches ALL the user's AI decks once (server `/decks/all`,
///     newest journal first) — the server is the source of truth for content.
///   * Fully revealed + resume/launch → advance to the newest not-yet-revealed
///     deck, with fresh scratch covers. All decks consumed → stay put.
///   * Untouched + already on newest → sticky (no pointless cycling).
///   * Untouched older deck with newer content → adopt the newest.
///   * Mid-reveal decks are protected (never yanked) until fully revealed.
///   * Tab switches never rotate; only cold start + background→foreground
///     resume re-evaluate (caller-side).
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
  ///  * Empty cache: returns null (caller falls back to verse decks).
  ///  * First paint (nothing on screen): adopts the newest deck.
  ///  * Mid-reveal (partially scratched): returns the current deck unchanged
  ///    (never yanked), even when a newer deck arrived in the background.
  ///  * Fully revealed: advances to the newest deck the user has NOT fully
  ///    revealed yet (excluding the current one). The new deck's card ids
  ///    are absent from the revealed set, so it paints with fresh scratch
  ///    covers. When every deck is consumed, stays on the current deck.
  ///  * Untouched: sticky when already on the newest; otherwise adopts the
  ///    newest (a new journal landed while the user never started the old).
  ///
  /// [revealedCardIds] and [currentCards] describe what's on screen.
  /// Tab switches must NOT call this — only cold start and
  /// background→foreground resume.
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
    if (decks.isEmpty) return null;

    final curId = currentDeckId;
    final hasContent = currentCards.isNotEmpty;
    final anyRevealed = revealedCardIds.isNotEmpty && !fullyRevealed;
    final newest = decks.first;
    final newestId = newest['deckId'] as String;

    Map<String, dynamic>? byId(String id) {
      for (final d in decks) {
        if (d['deckId'] == id) return d;
      }
      return null;
    }

    Set<String> cardIdsOf(Map<String, dynamic> payload) {
      return ((payload['insightCards'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .map((m) => (m['id'] as String?) ?? '')
              .where((id) => id.isNotEmpty))
          .toSet();
    }

    // Protected: user is mid-reveal (started but not finished) — rotation
    // never yanks it, even when a newer deck arrived while in background.
    if (hasContent &&
        anyRevealed &&
        curId != null &&
        curId.startsWith('deck_') &&
        byId(curId) != null) {
      final current = byId(curId)!;
      state['currentDeckId'] = current['deckId'];
      await _save(state);
      return _result(current);
    }

    // First paint or current deck gone (deleted server-side): adopt newest.
    if (!hasContent || curId == null || byId(curId) == null) {
      await _noteAdopted(state, decks, newestId,
          isChange: curId != null && curId != newestId);
      return _result(newest);
    }

    final curCardIds = cardIdsOf(byId(curId)!);
    final curUntouched = curCardIds.every((id) => !revealedCardIds.contains(id));
    final curFull = isDeckFullyRevealed(curCardIds, revealedCardIds);

    // Fully revealed: move on to the newest not-yet-revealed deck (not the
    // current one). New card ids are absent from the revealed set, so the
    // deck paints with fresh scratch covers — the "revealed state reset".
    // Nothing newer/unseen → stay put rather than cycling pointlessly.
    if (curFull) {
      for (final d in decks) {
        final id = d['deckId'] as String;
        if (id == curId) continue;
        if (!isDeckFullyRevealed(cardIdsOf(d), revealedCardIds)) {
          await _noteAdopted(state, decks, id, isChange: true);
          return _result(d);
        }
      }
      state['currentDeckId'] = curId;
      await _save(state);
      return _result(byId(curId)!);
    }

    // Untouched and already on the newest: sticky (no new content to show).
    if (curUntouched) {
      if (curId == newestId) {
        state['currentDeckId'] = curId;
        await _save(state);
        return _result(newest);
      }
      // Untouched older deck with newer content available: adopt newest.
      await _noteAdopted(state, decks, newestId, isChange: true);
      return _result(newest);
    }

    // Partially revealed but reached here (e.g. caller flags disagree with
    // the cache): protect the current deck.
    state['currentDeckId'] = curId;
    await _save(state);
    return _result(byId(curId)!);
  }

  /// Bookkeeping for adopting [deckId]: points the cursor at it, records it
  /// in today's window, and bumps the change counter only on a real change.
  static Future<void> _noteAdopted(
    Map<String, dynamic> state,
    List<Map<String, dynamic>> decks,
    String deckId, {
    required bool isChange,
  }) async {
    final idx = decks.indexWhere((d) => d['deckId'] == deckId);
    state['cursor'] = idx < 0 ? 0 : (idx + 1) % decks.length;
    state['currentDeckId'] = deckId;
    if (isChange) {
      final changesToday = (state['changesToday'] as int?) ?? 0;
      state['changesToday'] = changesToday + 1;
      final todayIds = (state['todayDeckIds'] as List? ?? [])
          .map((e) => e as String)
          .toList();
      if (!todayIds.contains(deckId)) todayIds.add(deckId);
      while (todayIds.length > decksPerDay) {
        todayIds.removeAt(0);
      }
      state['todayDeckIds'] = todayIds;
    }
    await _save(state);
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
