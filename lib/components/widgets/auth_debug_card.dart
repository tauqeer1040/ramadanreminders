import 'package:flutter/material.dart';
import '../../services/auth_debug_service.dart';
import '../../services/auth_service.dart';
import '../../services/deck_rotation_service.dart';
import '../../services/notification_service.dart';
import '../../services/push_reminder_service.dart';

class AuthDebugCard extends StatefulWidget {
  const AuthDebugCard({super.key});

  @override
  State<AuthDebugCard> createState() => _AuthDebugCardState();
}

class _AuthDebugCardState extends State<AuthDebugCard> {
  final _debug = AuthDebugService();
  bool _expanded = false;
  bool _decksExpanded = false;
  Map<String, dynamic>? _rotationState;
  bool _loadingRotation = false;

  @override
  void initState() {
    super.initState();
    _debug.addListener(_onDebugChanged);
    _refreshRotationState();
  }

  @override
  void dispose() {
    _debug.removeListener(_onDebugChanged);
    super.dispose();
  }

  Future<void> _refreshRotationState() async {
    setState(() => _loadingRotation = true);
    final state = await DeckRotationService.debugState();
    if (mounted) {
      setState(() {
        _rotationState = state;
        _loadingRotation = false;
      });
    }
  }

  Future<void> _resyncDecks() async {
    setState(() => _loadingRotation = true);
    await DeckRotationService.sync();
    await _refreshRotationState();
  }

  /// Flattened list of cached insight CARDS (newest deck first), one row per
  /// insight — 3 decks × 3 cards = 9 rows when the cache is fully loaded.
  List<Map<String, dynamic>> _cachedInsights() {
    final decks = (_rotationState?['decks'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final rows = <Map<String, dynamic>>[];
    for (final deck in decks) {
      final deckId = deck['deckId'] as String? ?? '?';
      final cards = deck['insightCards'] as List? ?? [];
      for (var i = 0; i < cards.length; i++) {
        final c = Map<String, dynamic>.from(cards[i] as Map);
        final preview = (c['quote'] ??
                c['insight'] ??
                c['explanation'] ??
                c['lesson'] ??
                c['reference'] ??
                '')
            .toString();
        rows.add({
          'deckId': deckId,
          'cardIndex': i + 1,
          'cardCount': cards.length,
          'preview': preview,
          'reference': (c['reference'] ?? c['storyReference'] ?? '').toString(),
        });
      }
    }
    return rows;
  }

  void _onDebugChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final uid = user?.uid ?? 'null';
    final isAnon = user?.isAnonymous ?? true;
    final email = user?.email ?? 'none';
    final photoURL = user?.photoURL ?? 'none';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _debug.lastError != null
              ? Colors.redAccent.withValues(alpha: 0.6)
              : (_debug.lastSignInSuccess
                  ? Colors.greenAccent.withValues(alpha: 0.6)
                  : Colors.white24),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    _debug.lastError != null
                        ? Icons.error_outline
                        : (_debug.lastSignInSuccess
                            ? Icons.check_circle_outline
                            : Icons.bug_report_outlined),
                    size: 16,
                    color: _debug.lastError != null
                        ? Colors.redAccent
                        : (_debug.lastSignInSuccess
                            ? Colors.greenAccent
                            : Colors.white54),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Auth Debug',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _debug.lastError != null
                          ? Colors.redAccent
                          : (_debug.lastSignInSuccess
                              ? Colors.greenAccent
                              : Colors.white54),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.white38,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _entry('UID', uid),
                  _entry('Anonymous', '$isAnon'),
                  _entry('Email', email),
                  _entry('Photo URL', photoURL),
                  const SizedBox(height: 8),
                  if (_debug.lastError != null) ...[
                    const Divider(color: Colors.redAccent, height: 1),
                    const SizedBox(height: 6),
                    _entry('LAST ERROR', _debug.lastError!, color: Colors.redAccent),
                    if (_debug.lastErrorDetails != null)
                      _entry('DETAILS', _debug.lastErrorDetails!, color: Colors.orangeAccent),
                    const SizedBox(height: 6),
                  ] else if (_debug.lastSignInSuccess) ...[
                    const Divider(color: Colors.greenAccent, height: 1),
                    const SizedBox(height: 6),
                    _entry('STATUS', 'Last sign-in succeeded', color: Colors.greenAccent),
                    const SizedBox(height: 6),
                  ],
                  const SizedBox(height: 4),
                  const Text(
                    'EVENT LOG',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white38,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_debug.events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'No events yet. Try signing in.',
                        style: TextStyle(fontSize: 11, color: Colors.white24),
                      ),
                    )
                  else
                    ..._debug.events.take(10).map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: _colorForType(e.type).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              e.type,
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: _colorForType(e.type),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              e.message,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white60,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => NotificationService.showDayNotificationNow(),
                          icon: const Icon(Icons.wb_sunny_outlined, size: 14),
                          label: const Text('Fire Day Notif', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.amberAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => NotificationService.showNightNotificationNow(),
                          icon: const Icon(Icons.dark_mode_outlined, size: 14),
                          label: const Text('Fire Night Notif', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.lightBlueAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => PushReminderService.sendTestPush(),
                    icon: const Icon(Icons.cloud_upload_outlined, size: 14),
                    label: const Text('Test Backend Push', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.tealAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── Deck rotation debug ──
                  InkWell(
                    onTap: () => setState(() => _decksExpanded = !_decksExpanded),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.style_outlined, size: 14, color: Colors.deepPurpleAccent),
                          const SizedBox(width: 6),
                          Text(
                            'Loaded Insights (${_cachedInsights().length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.deepPurpleAccent,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _decksExpanded ? Icons.expand_less : Icons.expand_more,
                            size: 16,
                            color: Colors.white38,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_decksExpanded) ...[
                    Row(
                      children: [
                        _rotationMeta('cursor', _rotationState?['cursor']),
                        const SizedBox(width: 12),
                        _rotationMeta('changesToday', _rotationState?['changesToday']),
                        const SizedBox(width: 12),
                        _rotationMeta('current', _rotationState?['currentDeckId']),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _loadingRotation ? null : _resyncDecks,
                          icon: _loadingRotation
                              ? const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5))
                              : const Icon(Icons.sync, size: 12),
                          label: const Text('Re-sync', style: TextStyle(fontSize: 10)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.deepPurpleAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_cachedInsights().isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'No cached insights yet — tap Re-sync (needs backend deploy).',
                          style: TextStyle(fontSize: 10, color: Colors.white24),
                        ),
                      )
                    else
                      ..._cachedInsights().take(30).toList().asMap().entries.map((entry) {
                        final i = entry.key;
                        final row = entry.value;
                        final deckId = row['deckId'] as String? ?? '?';
                        var preview = (row['preview'] as String? ?? '').trim();
                        if (preview.length > 58) preview = '${preview.substring(0, 58)}…';
                        final ref = (row['reference'] as String? ?? '').trim();
                        final isCurrent = deckId == (_rotationState?['currentDeckId'] ?? '');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 20,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (isCurrent ? Colors.deepPurpleAccent : Colors.white24).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: isCurrent ? Colors.deepPurpleAccent : Colors.white38,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  ref.isEmpty ? preview : '$preview — $ref',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isCurrent ? Colors.white : Colors.white60,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              Text(
                                '${row['cardIndex']}/${row['cardCount']}',
                                style: const TextStyle(fontSize: 9, color: Colors.white24),
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                  const SizedBox(height: 8),
                  const SizedBox(height: 8),
                  if (_debug.events.isNotEmpty)
                    TextButton.icon(
                      onPressed: _debug.clear,
                      icon: const Icon(Icons.clear_all, size: 14),
                      label: const Text('Clear Log', style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white38,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _entry(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color ?? Colors.white38,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 10,
                color: color ?? Colors.white70,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rotationMeta(String label, dynamic value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 9, color: Colors.white24, fontFamily: 'monospace'),
        ),
        Text(
          '${value ?? "—"}',
          style: const TextStyle(fontSize: 9, color: Colors.white54, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'SUCCESS':
      case 'LINK_OK':
      case 'FALLBACK_OK':
      case 'ANON':
        return Colors.greenAccent;
      case 'ERROR':
      case 'LINK_ERR':
        return Colors.redAccent;
      case 'CANCELLED':
        return Colors.orangeAccent;
      case 'ATTEMPT':
        return Colors.blueAccent;
      case 'TOKEN':
      case 'STATE':
        return Colors.cyanAccent;
      default:
        return Colors.white54;
    }
  }
}
