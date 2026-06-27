import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../core/app_background.dart';
import '../services/journal_service.dart';
import '../theme/app_theme.dart';
import 'journal_editor_screen.dart';
import 'widgets/mascot_empty_state.dart';

class JournalListScreen extends StatefulWidget {
  const JournalListScreen({super.key});

  @override
  State<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends State<JournalListScreen> {
  List<Map<String, String>> _allJournals = [];
  List<Map<String, String>> _filteredJournals = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _selectedDates = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadJournals();
  }

  Future<void> _loadJournals() async {
    setState(() => _isLoading = true);
    final journals = await JournalService.getAllLocalJournals();

    if (mounted) {
      setState(() {
        _allJournals = journals;
        _filteredJournals = journals;
        _isLoading = false;
      });
    }
  }

  void _filterJournals(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredJournals = _allJournals;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredJournals = _allJournals.where((j) {
        final text = j['text']!.toLowerCase();
        final date = j['date']!.toLowerCase();
        return text.contains(lowerQuery) || date.contains(lowerQuery);
      }).toList();
    });
  }

  void _openEditor({String? existingDate, String? existingText}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEditorScreen(
          initialDate: existingDate,
          initialText: existingText,
        ),
      ),
    );
    _loadJournals();
  }

  void _onTapJournal(int index) {
    if (_selectionMode) {
      _toggleSelection(index);
    } else {
      final journal = _filteredJournals[index];
      _openEditor(
        existingDate: journal['date'],
        existingText: journal['text'],
      );
    }
  }

  void _onLongPressJournal(int index) {
    HapticFeedback.mediumImpact();
    final date = _filteredJournals[index]['date']!;
    setState(() {
      _selectionMode = true;
      _selectedDates.add(date);
    });
  }

  void _toggleSelection(int index) {
    final date = _filteredJournals[index]['date']!;
    setState(() {
      if (_selectedDates.contains(date)) {
        _selectedDates.remove(date);
        if (_selectedDates.isEmpty) _selectionMode = false;
      } else {
        _selectedDates.add(date);
      }
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectedDates.clear();
      _selectionMode = false;
    });
  }

  Future<void> _batchToggleFavorite() async {
    HapticFeedback.lightImpact();
    for (final date in _selectedDates) {
      await JournalService.toggleFavorite(date);
    }
    _cancelSelection();
    _loadJournals();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedDates.length} journal(s) updated'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFD4EDDA),
        ),
      );
    }
  }

  void _batchDelete() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ${_selectedDates.length} entr${_selectedDates.length == 1 ? 'y' : 'ies'}?',
          style: const TextStyle(color: AppTheme.starWhite),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: AppTheme.ghostSilver),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.neonPurple)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (final date in _selectedDates) {
                await JournalService.deleteLocalJournal(date);
              }
              _cancelSelection();
              _loadJournals();
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _selectionMode ? _buildSelectionAppBar(cs) : _buildSearchAppBar(cs),
      body: AppBackground(
        child: _isLoading
            ? _buildSkeletonGrid(cs)
            : _filteredJournals.isEmpty
            ? _buildEmptyState(cs)
            : _buildGrid(cs),
      ),
    );
  }

  PreferredSizeWidget _buildSearchAppBar(ColorScheme cs) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      title: TextField(
        controller: _searchController,
        onChanged: _filterJournals,
        decoration: InputDecoration(
          hintText: "Search your journals...",
          border: InputBorder.none,
          hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
          icon: Icon(Icons.search, color: cs.onSurface),
        ),
        style: TextStyle(color: cs.onSurface, fontSize: 16),
      ),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(ColorScheme cs) {
    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: AppTheme.starWhite),
        onPressed: _cancelSelection,
      ),
      title: Text(
        '${_selectedDates.length} selected',
        style: const TextStyle(color: AppTheme.starWhite, fontSize: 16, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.star_rounded, color: AppTheme.starGold),
          onPressed: _batchToggleFavorite,
          tooltip: 'Toggle favorite',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935)),
          onPressed: _batchDelete,
          tooltip: 'Delete selected',
        ),
      ],
    );
  }

  Widget _buildEmptyState(ColorScheme cs) {
    return MascotEmptyState(
      message: 'No journals yet.\nYour first entry is waiting.',
      actionLabel: 'Write your first entry',
      onAction: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const JournalEditorScreen()),
        ).then((_) => _loadJournals());
      },
    );
  }

  Widget _buildSkeletonGrid(ColorScheme cs) {
    return Shimmer.fromColors(
      baseColor: cs.onSurface.withValues(alpha: 0.06),
      highlightColor: cs.onSurface.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: 6,
          itemBuilder: (context, index) => Container(
            height: 120 + (index % 3) * 40.0,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: MasonryGridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: _filteredJournals.length,
        itemBuilder: (context, index) {
          final journal = _filteredJournals[index];
          final date = journal['date'] ?? '';
          final isSelected = _selectedDates.contains(date);
          return GestureDetector(
            onTap: () => _onTapJournal(index),
            onLongPress: () => _onLongPressJournal(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.neonPurple.withValues(alpha: 0.25)
                    : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.neonPurple.withValues(alpha: 0.6)
                      : cs.outlineVariant.withValues(alpha: 0.5),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          JournalService.formatDisplayDate(journal['date'] ?? ''),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppTheme.neonPurple : cs.onSurface,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppTheme.neonPurple,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.check, size: 14, color: Colors.white),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    journal['text'] ?? '',
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurface,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
