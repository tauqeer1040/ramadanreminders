import 'package:flutter/material.dart';
import '../../services/auth_debug_service.dart';
import '../../services/auth_service.dart';

class AuthDebugCard extends StatefulWidget {
  const AuthDebugCard({super.key});

  @override
  State<AuthDebugCard> createState() => _AuthDebugCardState();
}

class _AuthDebugCardState extends State<AuthDebugCard> {
  final _debug = AuthDebugService();
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _debug.addListener(_onDebugChanged);
  }

  @override
  void dispose() {
    _debug.removeListener(_onDebugChanged);
    super.dispose();
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
