import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bullet_item.dart';
import '../services/journal_service.dart';
import '../core/app_background.dart';

class _CardColorTheme {
  final Color bg;
  final Color text;
  final Color accent;
  const _CardColorTheme({required this.bg, required this.text, required this.accent});
}

const List<_CardColorTheme> _cardColorSchemes = [
  _CardColorTheme(bg: Color(0xFFD6DF7E), text: Color(0xFF13441A), accent: Color(0xFF187B25)),
  _CardColorTheme(bg: Color(0xFFFAA49A), text: Color(0xFF4E1106), accent: Color(0xFFC4391D)),
  _CardColorTheme(bg: Color(0xFFA0C4FF), text: Color(0xFF00154F), accent: Color(0xFF0052FF)),
  _CardColorTheme(bg: Color(0xFFFFF0B2), text: Color(0xFF4E2E00), accent: Color(0xFFA86200)),
];

class JournalHistoryScreen extends StatefulWidget {
  const JournalHistoryScreen({super.key});

  @override
  State<JournalHistoryScreen> createState() => _JournalHistoryScreenState();
}

class _JournalHistoryScreenState extends State<JournalHistoryScreen> {
  final JournalService _journalService = JournalService();
  List<String> _dates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDates();
  }

  Future<void> _loadDates() async {
    final dates = await _journalService.getStoredDates();
    if (mounted) {
      setState(() {
        _dates = dates;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Journal History',
          style: textTheme.titleLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: colorScheme.primary),
      ),
      body: AppBackground(
        child: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _dates.isEmpty
          ? Center(
              child: Text(
                'No entries found yet.',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                final date = _dates[index];
                return _buildDateCard(date, index, colorScheme, textTheme);
              },
            ),
      ),
    );
  }

  Widget _buildDateCard(
    String dateStr,
    int index,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final scheme = _cardColorSchemes[index % _cardColorSchemes.length];
    DateTime? date;
    try {
      date = DateTime.parse(dateStr);
    } catch (_) {}

    final formattedDate = date != null
        ? DateFormat('EEEE, MMMM d, y').format(date)
        : dateStr;

    return Card(
      color: scheme.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.text),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          formattedDate,
          style: textTheme.titleMedium?.copyWith(
            color: scheme.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconColor: scheme.text,
        collapsedIconColor: scheme.text.withValues(alpha: 0.6),
        children: [
          FutureBuilder<Map<String, dynamic>>(
            future: _loadEntryDetails(dateStr),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              if (!snapshot.hasData) return const SizedBox();

              final gratitude = snapshot.data!['gratitude'] as String;
              final tasks = snapshot.data!['tasks'] as List<BulletItem>;

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (gratitude.isNotEmpty) ...[
                      Text(
                        "✦ Gratitude",
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gratitude,
                        style: textTheme.bodyLarge?.copyWith(
                          color: scheme.text,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (tasks.isNotEmpty) ...[
                      Text(
                        "✦ Tasks & Reflections",
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...tasks.map(
                        (task) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                task.completed
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                size: 16,
                                color: task.completed
                                    ? scheme.accent
                                    : scheme.text.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task.content,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: task.completed
                                        ? scheme.text.withValues(alpha: 0.5)
                                        : scheme.text,
                                    decoration: task.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _loadEntryDetails(String date) async {
    final gratitude = await _journalService.loadJournalGratitude(date);
    final tasks = await _journalService.loadJournalTasks(date);
    return {'gratitude': gratitude, 'tasks': tasks};
  }
}
