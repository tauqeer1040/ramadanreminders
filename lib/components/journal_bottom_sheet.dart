import 'package:flutter/material.dart';
import '../services/journal_service.dart';
import 'journal_list_screen.dart';
import '../core/app_background.dart';

class JournalBottomSheet extends StatefulWidget {
  const JournalBottomSheet({super.key});

  @override
  State<JournalBottomSheet> createState() => _JournalBottomSheetState();
}

class _JournalBottomSheetState extends State<JournalBottomSheet> {
  late TextEditingController _controller;
  late String _journalId;
  double _lastKeyboardInset = 0;

  final _suggestions = [
    "I had a good day today",
    "Gratitude:",
    "Things to improve upon",
    "Today I learned...",
    "I felt...",
    "Something that made me smile",
    "My prayer today",
    "A challenge I faced",
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _journalId = DateTime.now().toIso8601String();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    JournalService.saveLocalJournalWithId(_journalId, text);
  }

  void _selectSuggestion(String suggestion) {
    final current = _controller.text;
    if (current.isEmpty) {
      _controller.text = suggestion;
    } else {
      _controller.text = '$current\n$suggestion';
    }
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    _onTextChanged(_controller.text);
  }

  void _openHistory() {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JournalListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset > 0) _lastKeyboardInset = bottomInset;

    return AppBackground(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    // const Spacer(),
                    SizedBox(width:16),
                    Text(
                      'New Journal',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: const Color(0xFFF5F5F0)),
                    ),
                    const Spacer(),
                      IconButton(
                        icon: Icon(Icons.history_rounded, color: const Color(0xFFF5F5F0)),
                        onPressed: _openHistory,
                        style: IconButton.styleFrom(backgroundColor: Colors.transparent),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Writing area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: TextField(
                    controller: _controller,
                    onChanged: _onTextChanged,
                    autofocus: true,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(fontSize: 18, color: cs.onSurface, height: 1.6),
                    decoration: InputDecoration(
                      hintText: "Write your thoughts, struggles, or gratitude here...",
                      hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 18),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),

              // Suggestion pills
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow.withValues(alpha: 0.6),
                  border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3))),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prompt ideas', style: tt.labelMedium),
                    const SizedBox(height: 10),
                    if (bottomInset > 0)
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) => ActionChip(
                            label: Text(_suggestions[i], style: tt.labelSmall?.copyWith(color: const Color(0xFFF5F5F0))),
                            onPressed: () => _selectSuggestion(_suggestions[i]),
                            backgroundColor: cs.surfaceContainerHigh,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestions.map((s) => ActionChip(
                          label: Text(s, style: tt.labelSmall?.copyWith(color: const Color(0xFFF5F5F0))),
                          onPressed: () => _selectSuggestion(s),
                          backgroundColor: cs.surfaceContainerHigh,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        )).toList(),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Column(
                  children: [
                    Text(
                      'Journal auto saved',
                      style: tt.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 4),
                    // Icon(Icons.check_circle_outline_rounded, color: cs.onSurfaceVariant.withValues(alpha: 0.4), size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
