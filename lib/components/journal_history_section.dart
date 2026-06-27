import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/journal_service.dart';
import '../theme/app_theme.dart';
import 'journal_list_screen.dart';
import 'widgets/mascot_empty_state.dart';

({String title, String body}) _splitEntry(String text) {
  final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.isEmpty) return (title: '', body: '');
  if (lines.length == 1) return (title: lines[0], body: '');
  return (title: lines[0], body: lines.skip(1).join(' '));
}

class _JournalEntryRow extends StatefulWidget {
  final Map<String, String> journal;
  final VoidCallback onTap;
  final VoidCallback onChanged;

  const _JournalEntryRow({
    required this.journal,
    required this.onTap,
    required this.onChanged,
  });

  @override
  State<_JournalEntryRow> createState() => _JournalEntryRowState();
}

class _JournalEntryRowState extends State<_JournalEntryRow> {
  bool _isFavorited = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadFav();
  }

  Future<void> _loadFav() async {
    final date = widget.journal['date'] ?? '';
    final fav = await JournalService.isFavorited(date);
    if (mounted) setState(() { _isFavorited = fav; _loaded = true; });
  }

  void _showMenu() {
    final date = widget.journal['date'] ?? '';
    final text = widget.journal['text'] ?? '';

    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              _menuItem(
                icon: _isFavorited ? Icons.star_rounded : Icons.star_border_rounded,
                label: _isFavorited ? 'Unfavorite' : 'Favorite',
                color: AppTheme.starGold,
                onTap: () async {
                  Navigator.pop(ctx);
                  await JournalService.toggleFavorite(date);
                  widget.onChanged();
                  if (mounted) setState(() => _isFavorited = !_isFavorited);
                },
              ),
              _menuItem(
                icon: Icons.copy_rounded,
                label: 'Copy to clipboard',
                color: Colors.white,
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: text));
                  HapticFeedback.lightImpact();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)),
                    );
                  }
                },
              ),
              _menuItem(
                icon: Icons.share_rounded,
                label: 'Share',
                color: Colors.white,
                onTap: () {
                  Navigator.pop(ctx);
                  Share.share(text);
                },
              ),
              _menuItem(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: const Color(0xFFE53935),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(date);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String date) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete entry?', style: TextStyle(color: AppTheme.starWhite)),
        content: const Text('This cannot be undone.', style: TextStyle(color: AppTheme.ghostSilver)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.neonPurple)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await JournalService.deleteLocalJournal(date);
              widget.onChanged();
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label, style: const TextStyle(color: AppTheme.starWhite, fontSize: 15, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final text = widget.journal['text'] ?? '';
    final dateStr = widget.journal['date'] ?? '';
    final parts = _splitEntry(text);
    DateTime? date;
    try { date = DateTime.parse(dateStr); } catch (_) {}

    final dayName = date != null ? DateFormat('EEE').format(date).toUpperCase() : '';
    final dayNum = date != null ? '${date.day}' : '';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onLongPress: _showMenu,
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                        Text(dayName, style: tt.labelSmall?.copyWith(
                          color: Colors.black.withValues(alpha: 0.50),
                          fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.5,
                        )),
                        const SizedBox(height: 1),
                        Text(dayNum, style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.black.withValues(alpha: 0.70), fontSize: 22, height: 1,
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (parts.title.isNotEmpty)
                          Text(parts.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.92), fontSize: 14.5, height: 1.2,
                            ),
                          ),
                        if (parts.title.isNotEmpty && parts.body.isNotEmpty) const SizedBox(height: 4),
                        if (parts.body.isNotEmpty)
                          Text(parts.body, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.48), fontSize: 13, height: 1.4,
                            ),
                          )
                        else if (parts.title.isEmpty)
                          Text(text, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.48), fontSize: 13, height: 1.4,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_loaded && _isFavorited)
                    Icon(Icons.star_rounded, size: 16, color: AppTheme.starGold.withValues(alpha: 0.7)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class JournalHistorySection extends StatefulWidget {
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

  void _refresh() {
    setState(() {
      _future = JournalService.getAllLocalJournals();
    });
  }

  void _openList() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JournalListScreen()),
    ).then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return FutureBuilder<List<Map<String, String>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox.shrink();
        final all = snap.data ?? [];
        if (all.isEmpty) {
          return MascotEmptyState(
            message: 'No entries yet.\nTap the + button to write your first journal.',
            mascotSize: 80,
          );
        }

        final shown = all.take(widget.maxEntries).toList();

        return ClipRRect(
          borderRadius: BorderRadius.circular(0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('History', style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.85), letterSpacing: 0.2,
                    )),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_note_rounded, size: 18,
                      color: AppTheme.neonPurple.withValues(alpha: 0.8)),
                  ],
                ),
                const SizedBox(height: 12),
                ...shown.map((j) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _JournalEntryRow(
                    journal: j,
                    onTap: _openList,
                    onChanged: _refresh,
                  ),
                )),
                GestureDetector(
                  onTap: _openList,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'see all diaries',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
          ),
        );
      },
    );
  }
}
