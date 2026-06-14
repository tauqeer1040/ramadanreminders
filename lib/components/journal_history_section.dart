import 'dart:math';
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

/// Returns a deterministic accent colour for a journal entry based on its text.
Color _entryAccent(String text) {
  const palette = [
    Color(0xFF9D50FF), // neon purple
    Color(0xFF26C6DA), // cyan
    Color(0xFF66BB6A), // green
    Color(0xFFFFB300), // amber
    Color(0xFFFF6B35), // orange
    Color(0xFF5C6BC0), // indigo
    Color(0xFFAB47BC), // purple
    Color(0xFF26A69A), // teal
  ];
  final idx = text.hashCode.abs() % palette.length;
  return palette[idx];
}

// ─────────────────────────────────────────────────────────────────────────────
// Coloured swatch thumbnail (stands in for a photo)
// ─────────────────────────────────────────────────────────────────────────────

class _SwatchThumb extends StatelessWidget {
  final Color color;
  final String text;

  const _SwatchThumb({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    // We paint a mini "word cloud" look with 3–4 words in the accent colour.
    final words = text.trim().split(RegExp(r'\s+')).take(4).toList();
    final rng = Random(text.hashCode);

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.20), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Decorative background circles
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.18),
              ),
            ),
          ),
          Positioned(
            left: -4,
            bottom: -4,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
              ),
            ),
          ),
          // Word snippets
          ...List.generate(min(words.length, 3), (i) {
            final angle = (rng.nextDouble() - 0.5) * 0.35;
            final tx = 6.0 + rng.nextDouble() * 24;
            final ty = 10.0 + i * 18.0;
            return Positioned(
              left: tx,
              top: ty,
              child: Transform.rotate(
                angle: angle,
                child: Text(
                  words[i],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.75),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
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
    final accent = _entryAccent(text);

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
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

            const SizedBox(width: 12),

            // ── Colour swatch thumbnail ───────────────────────────────
            _SwatchThumb(color: accent, text: parts.title.isNotEmpty ? parts.title : text),
          ],
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

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section header ──────────────────────────────────────
              Row(
                children: [
                  Text(
                    'Journal',
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
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.neonPurple.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.neonPurple.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View all ${all.length} entries',
                          style: tt.bodyMedium?.copyWith(
                            color: AppTheme.neonPurple,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded,
                            size: 16, color: AppTheme.neonPurple),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
