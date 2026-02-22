import 'package:flutter/material.dart';
import '../models/bullet_item.dart';
import '../services/journal_service.dart';
import 'journal_history_screen.dart';

class JournalEntry extends StatefulWidget {
  const JournalEntry({super.key});

  @override
  State<JournalEntry> createState() => _JournalEntryState();
}

class _JournalEntryState extends State<JournalEntry> {
  List<BulletItem> _items = [];
  final TextEditingController _newItemController = TextEditingController();
  final TextEditingController _gratitudeController = TextEditingController();
  final JournalService _journalService = JournalService();
  final String _todayKey = DateTime.now().toIso8601String().split('T')[0];

  @override
  void initState() {
    super.initState();
    _loadData();
    _gratitudeController.addListener(_saveGratitude);
  }

  @override
  void dispose() {
    _gratitudeController.removeListener(_saveGratitude);
    _gratitudeController.dispose();
    _newItemController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final gratitude = await _journalService.loadJournalGratitude(_todayKey);
    final tasks = await _journalService.loadJournalTasks(_todayKey);
    if (mounted) {
      setState(() {
        _gratitudeController.text = gratitude;
        _items = tasks;
      });
    }
  }

  void _saveGratitude() {
    _journalService.saveJournalGratitude(_todayKey, _gratitudeController.text);
  }

  void _saveTasks() {
    _journalService.saveJournalTasks(_todayKey, _items);
  }

  void _addItem() {
    if (_newItemController.text.trim().isEmpty) return;
    setState(() {
      _items.add(
        BulletItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: _newItemController.text,
        ),
      );
      _newItemController.clear();
    });
    _saveTasks();
  }

  void _toggleItem(String id) {
    setState(() {
      final item = _items.firstWhere((i) => i.id == id);
      item.completed = !item.completed;
    });
    _saveTasks();
  }

  void _removeItem(String id) {
    setState(() => _items.removeWhere((i) => i.id == id));
    _saveTasks();
  }

  void _manualSave() {
    _saveGratitude();
    _saveTasks();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Journal saved successfully!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Journal",
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: _manualSave,
                    tooltip: 'Save Journal',
                  ),
                  IconButton(
                    icon: const Icon(Icons.history),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const JournalHistoryScreen(),
                        ),
                      );
                    },
                    tooltip: 'View History',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Gratitude Section
          Text(
            "✦ Today I am grateful for...",
            style: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _gratitudeController,
            maxLines: 3,
            style: TextStyle(color: colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: "Write your gratitude here...",
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colorScheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Bullet Items
          Text(
            "✦ Reflections & Tasks",
            style: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 12),

          ..._items.map((item) => _buildBulletItem(item)),

          // Add new item
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newItemController,
                  style: TextStyle(color: colorScheme.onSurface),
                  onSubmitted: (_) => _addItem(),
                  decoration: InputDecoration(
                    hintText: "Add a new entry...",
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _addItem, icon: const Icon(Icons.add)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(BulletItem item) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: item.completed
                  ? colorScheme.secondaryContainer
                  : colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: item.completed
                    ? colorScheme.secondary.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleItem(item.id),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.completed
                          ? colorScheme.secondary
                          : Colors.transparent,
                      border: Border.all(
                        color: item.completed
                            ? colorScheme.secondary
                            : colorScheme.outline,
                        width: 2,
                      ),
                    ),
                    child: item.completed
                        ? Icon(
                            Icons.check,
                            size: 16,
                            color: colorScheme.onSecondary,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.content,
                    style: textTheme.bodyMedium?.copyWith(
                      color: item.completed
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                          : colorScheme.onSurfaceVariant,
                      decoration: item.completed
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () => _removeItem(item.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
