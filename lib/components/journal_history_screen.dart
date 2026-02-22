import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bullet_item.dart';
import '../services/journal_service.dart';

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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
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
      body: _isLoading
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
                return _buildDateCard(date, colorScheme, textTheme);
              },
            ),
    );
  }

  Widget _buildDateCard(
    String dateStr,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    DateTime? date;
    try {
      date = DateTime.parse(dateStr);
    } catch (_) {}

    final formattedDate = date != null
        ? DateFormat('EEEE, MMMM d, y').format(date)
        : dateStr;

    return Card(
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          formattedDate,
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconColor: colorScheme.primary,
        collapsedIconColor: colorScheme.onSurfaceVariant,
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
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gratitude,
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (tasks.isNotEmpty) ...[
                      Text(
                        "✦ Tasks & Reflections",
                        style: textTheme.labelLarge?.copyWith(
                          color: colorScheme.primary,
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
                                    ? colorScheme.secondary
                                    : colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  task.content,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: task.completed
                                        ? colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.5)
                                        : colorScheme.onSurface,
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
