import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/journal_service.dart';
import '../theme/app_theme.dart';
import 'journal_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Splits `text` into a title (first non-empty line) and a body (the rest).
({String title, String body}) _splitEntry(String text) {
  final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.isEmpty) return (title: '', body: '');
  if (lines.length == 1) return (title: lines[0], body: '');
  return (title: lines[0], body: lines.skip(1).join(' '));
}

// ─────────────────────────────────────────────────────────────────────────────
// Single entry row
// ─────────────────────────────────────────────────────────────────────────────

class _JournalEntryRow extends StatelessWidget {
  final Map<String, String> journal;
  final VoidCallback onTap;

  const _JournalEntryRow({required this.journal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final text = journal['text'] ?? '';
    final dateStr = journal['date'] ?? '';
    final parts = _splitEntry(text);
    DateTime? date;
    try {
      date = DateTime.parse(dateStr);
    } catch (_) {}

    final dayName = date != null ? DateFormat('EEE').format(date).toUpperCase() : '';
    final dayNum = date != null ? '${date.day}' : '';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Date column ─────────────────────────────────────────
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName,
                    style: tt.labelSmall?.copyWith(
                      color: Colors.black.withValues(alpha: 0.50),
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    dayNum,
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black.withValues(alpha: 0.70),
                      fontSize: 22,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 14),

            // ── Text content ─────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title (first line)
                  if (parts.title.isNotEmpty)
                    Text(
                      parts.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 14.5,
                        height: 1.2,
                      ),
                    ),

                  if (parts.title.isNotEmpty && parts.body.isNotEmpty)
                    const SizedBox(height: 4),

                  // Body preview (rest of text)
                  if (parts.body.isNotEmpty)
                    Text(
                      parts.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    )
                  else if (parts.title.isEmpty)
                    Text(
                      text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.48),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),

            ],
          ),
        ),
      ),
    ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

class JournalHistorySection extends StatefulWidget {
  /// Maximum number of recent entries to show inline.
  final int maxEntries;

  const JournalHistorySection({super.key, this.maxEntries = 3});

  @override
  State<JournalHistorySection> createState() => _JournalHistorySectionState();
}

class _JournalHistorySectionState extends State<JournalHistorySection> {
  late Future<List<Map<String, String>>> _future;

  @override
  void initState() {
    super.initState();
    _future = JournalService.getAllLocalJournals();
  }

  void _openList() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JournalListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return FutureBuilder<List<Map<String, String>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final all = snap.data ?? [];
        if (all.isEmpty) return const SizedBox.shrink();

        // Take most recent N entries
        final shown = all.take(widget.maxEntries).toList();

        return Container(
          width: double.infinity,
          color: Colors.black.withValues(alpha: 0.3),
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section header ──────────────────────────────────────
              Row(
                children: [
                  Text(
                    'History',
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.edit_note_rounded,
                    size: 18,
                    color: AppTheme.neonPurple.withValues(alpha: 0.8),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Entries ─────────────────────────────────────────────
              ...shown.map((j) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _JournalEntryRow(journal: j, onTap: _openList),
              )),

              // ── "View all" footer pill ──────────────────────────────
              if (all.length > widget.maxEntries)
                GestureDetector(
                  onTap: _openList,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View all ${all.length} entries',
                          style: tt.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded,
                            size: 14, color: Colors.white.withValues(alpha: 0.4)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          ),
        );
      },
    );
  }
}
