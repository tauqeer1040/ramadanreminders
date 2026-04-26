import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../services/journal_service.dart';
import 'journal_editor_screen.dart';

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
    // Navigate to full-screen editor
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEditorScreen(
          initialDate: existingDate,
          initialText: existingText,
        ),
      ),
    );
    // Reload journals when returning just in case they created/edited one
    _loadJournals();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Using a darker, keep-like surface variation
    final bgColor = cs.surfaceContainerLowest;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          onChanged: _filterJournals,
          decoration: InputDecoration(
            hintText: "Search your journals...",
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            icon: Icon(Icons.search, color: cs.onSurfaceVariant),
          ),
          style: TextStyle(color: cs.onSurface, fontSize: 16),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredJournals.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notes,
                    size: 64,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No journals found",
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: MasonryGridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                itemCount: _filteredJournals.length,
                itemBuilder: (context, index) {
                  final journal = _filteredJournals[index];
                  return GestureDetector(
                    onTap: () => _openEditor(
                      existingDate: journal['date'],
                      existingText: journal['text'],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            JournalService.formatDisplayDate(journal['date'] ?? ''),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurfaceVariant,
                            ),
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
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: cs.primaryContainer,
        child: Icon(Icons.add, color: cs.onPrimaryContainer),
      ),
    );
  }
}
