import 'package:flutter/material.dart';
import '../services/journal_service.dart';

class JournalEditorScreen extends StatefulWidget {
  final String? initialDate;
  final String? initialText;

  const JournalEditorScreen({super.key, this.initialDate, this.initialText});

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  late TextEditingController _controller;
  bool _isSaving = false;
  // Generate a totally unique ID for new journals so users can create multiple per day
  late String _journalDate;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');

    // If no date passed, it's a completely new journal. Use precise timestamp as ID
    if (widget.initialDate == null) {
      _journalDate = DateTime.now().toIso8601String();
    } else {
      _journalDate = widget.initialDate!;
    }
  }

  void _onTextChanged(String text) async {
    if (mounted) setState(() => _isSaving = true);

    // Save locally instantly on every keystroke (marks the dirty flag for sync) using the unique ID.
    // Syncing to the cloud still happens in batches later (e.g., at midnight or on app launch).
    await JournalService.saveLocalJournalWithId(_journalDate, text);

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = cs.surfaceContainerLowest;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initialDate == null ? "New Journal" : JournalService.formatDisplayDate(_journalDate),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: _onTextChanged,
                  autofocus: widget.initialDate == null, // Auto-focus if writing a new one
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontSize: 18,
                    color: cs.onSurface,
                    height: 1.6,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        "Write your thoughts, struggles, or gratitude here...",
                    hintStyle: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                      fontSize: 18,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
