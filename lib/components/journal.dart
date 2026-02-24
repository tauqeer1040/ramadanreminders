import 'package:flutter/material.dart';
import '../services/journal_service.dart';
import 'journal_history_screen.dart';
import 'shared/bouncing_widget.dart';

/// Today's gratitude journal — a simple text-field for daily reflection.
///
/// Tasks have been moved to [TaskCarousel] on the homepage.
class JournalEntry extends StatefulWidget {
  const JournalEntry({super.key});

  @override
  State<JournalEntry> createState() => _JournalEntryState();
}

class _JournalEntryState extends State<JournalEntry> {
  final TextEditingController _gratitudeController = TextEditingController();
  final JournalService _journalService = JournalService();
  final String _todayKey = DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    _loadGratitude();
    _gratitudeController.addListener(_saveGratitude);
  }

  @override
  void dispose() {
    _gratitudeController.removeListener(_saveGratitude);
    _gratitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadGratitude() async {
    final gratitude = await _journalService.loadJournalGratitude(_todayKey);
    if (mounted) {
      setState(() => _gratitudeController.text = gratitude);
    }
  }

  void _saveGratitude() {
    _journalService.saveJournalGratitude(_todayKey, _gratitudeController.text);
  }

  void _manualSave() {
    _saveGratitude();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Journal saved!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Journal",
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              Row(
                children: [
                  BouncingWidget(
                    onPressed: _manualSave,
                    child: IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: () {},
                      tooltip: 'Save Journal',
                    ),
                  ),
                  BouncingWidget(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const JournalHistoryScreen(),
                        ),
                      );
                    },
                    child: IconButton(
                      icon: const Icon(Icons.history),
                      onPressed: () {},
                      tooltip: 'View History',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Gratitude prompt
          Text(
            '✦ Today I am grateful for...',
            style: tt.labelLarge?.copyWith(color: cs.primary),
          ),
          const SizedBox(height: 8),

          // Gratitude text field
          TextField(
            controller: _gratitudeController,
            maxLines: 3,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: 'Write your gratitude here...',
              hintStyle: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: cs.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: cs.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
