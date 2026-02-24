import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bullet_item.dart';
import '../services/journal_service.dart';
import 'task_card.dart';

/// Horizontal carousel of daily tasks, shown on the homepage.
///
/// Loads/saves tasks via [JournalService] (date-keyed SharedPreferences).
/// Seeds 3 defaults if no tasks exist for today.
class TaskCarousel extends StatefulWidget {
  final VoidCallback? onTaskCompleted;

  const TaskCarousel({super.key, this.onTaskCompleted});

  @override
  State<TaskCarousel> createState() => _TaskCarouselState();
}

class _TaskCarouselState extends State<TaskCarousel> {
  final JournalService _service = JournalService();
  final String _todayKey = DateTime.now().toIso8601String().split('T')[0];
  final TextEditingController _addController = TextEditingController();
  final CarouselController _carouselController = CarouselController(
    initialItem: 0,
  );

  List<BulletItem> _tasks = [];
  bool _loading = true;
  int _focusedIndex = 0;
  List<String> _availableImages = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addController.dispose();
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestJson);
      _availableImages = manifestMap.keys
          .where(
            (key) =>
                key.startsWith('assets/photos/images/') &&
                key.toLowerCase().endsWith('.jpeg'),
          )
          .toList();
    } catch (_) {
      _availableImages = [
        'assets/photos/images/ethreialbloom1.jpeg',
        'assets/photos/images/EtherealFlower.jpeg',
        'assets/photos/images/DelicateOrangeFlowerinBloom.jpeg',
        'assets/photos/images/EtherealFlower-1-.jpeg',
      ];
    }

    var tasks = await _service.loadJournalTasks(_todayKey);
    if (tasks.isEmpty) {
      tasks = _defaultTasks();
      await _service.saveJournalTasks(_todayKey, tasks);
    }
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _loading = false;
      });
    }
  }

  String _getRandomImage([String? previousImage]) {
    if (_availableImages.isEmpty) {
      return 'assets/photos/images/ethreialbloom1.jpeg';
    }

    String? lastImage = previousImage;
    if (lastImage == null && _tasks.isNotEmpty) {
      lastImage = _tasks.last.bgImage;
    }

    if (lastImage == null || _availableImages.length <= 1) {
      return _availableImages[_random.nextInt(_availableImages.length)];
    }

    String nextImage;
    do {
      nextImage = _availableImages[_random.nextInt(_availableImages.length)];
    } while (nextImage == lastImage);

    return nextImage;
  }

  List<BulletItem> _defaultTasks() => [
    BulletItem(
      id: 'default_1',
      content: 'Compliment a Stranger',
      bgImage: 'assets/photos/images/ethreialbloom1.jpeg',
    ),
    BulletItem(
      id: 'default_2',
      content: 'Read Quran for 15 mins',
      bgImage: 'assets/photos/images/EtherealFlower.jpeg',
    ),
    BulletItem(
      id: 'default_3',
      content: 'Give Charity',
      bgImage: 'assets/photos/images/DelicateOrangeFlowerinBloom.jpeg',
    ),
  ];

  void _toggle(int index) {
    final newState = !_tasks[index].completed;
    setState(() => _tasks[index].completed = newState);
    _service.saveJournalTasks(_todayKey, _tasks);

    if (newState) {
      HapticFeedback.heavyImpact();
      widget.onTaskCompleted?.call();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _delete(int index) {
    final item = _tasks[index];
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Remove "${item.content}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        setState(() => _tasks.removeAt(index));
        _service.saveJournalTasks(_todayKey, _tasks);
      }
    });
  }

  Future<void> _showAddTaskDialog() async {
    bool isCustomMode = false;
    final contentController = TextEditingController();

    final popularTasks = [
      'Read Quran for 15 mins',
      'Give Charity',
      'Compliment a Stranger',
      'Pray Taraweeh',
      'Smile at someone',
      'Call Family',
      'Help a neighbor',
      'Forgive someone',
      'Dhikr 100 times',
      'Feed an animal',
    ];

    final String? newTask = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (!isCustomMode) {
              return AlertDialog(
                title: const Text('Add Task'),
                content: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...popularTasks.map((task) {
                        return ActionChip(
                          label: Text(task),
                          onPressed: () {
                            Navigator.pop(context, task);
                          },
                        );
                      }),
                      ActionChip(
                        label: const Text(
                          'Custom +',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        onPressed: () {
                          setState(() {
                            isCustomMode = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Custom Task'),
              content: TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Task (e.g. Read Surah Yaseen)',
                ),
                textCapitalization: TextCapitalization.sentences,
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final content = contentController.text.trim();
                    if (content.isNotEmpty) {
                      Navigator.pop(context, content);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (newTask != null && newTask.isNotEmpty && mounted) {
      setState(() {
        _tasks.add(
          BulletItem(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            content: newTask,
            bgImage: _getRandomImage(),
          ),
        );
        _focusedIndex = _tasks.length - 1;
      });
      _service.saveJournalTasks(_todayKey, _tasks);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _carouselController.animateToItem(
          _focusedIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return CarouselView.weighted(
      controller: _carouselController,
      flexWeights: const <int>[5, 1, 1],
      itemSnapping: true,
      children: [
        for (int i = 0; i < _tasks.length; i++)
          TaskCard(
            key: ValueKey(_tasks[i].id),
            text: _tasks[i].content,
            completed: _tasks[i].completed,
            isFocused: i == _focusedIndex,
            bgImage: _tasks[i].bgImage ?? _getRandomImage(),
            onTap: () => _toggle(i),
            onFocus: () {
              setState(() => _focusedIndex = i);
              _carouselController.animateToItem(
                i,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
            onDelete: () => _delete(i),
            index: i,
          ),
        _AddTaskCard(
          onTap: () async {
            HapticFeedback.lightImpact();
            await _showAddTaskDialog();
          },
          onFocus: () {
            setState(() => _focusedIndex = _tasks.length);
            _carouselController.animateToItem(
              _tasks.length,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        ),
        const _DecorCard(icon: Icons.star_border_rounded),
        const _DecorCard(icon: Icons.bedtime_outlined),
      ],
    );
  }
}

class _AddTaskCard extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onFocus;
  const _AddTaskCard({required this.onTap, required this.onFocus});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCentered = constraints.maxWidth > 160;
        final double textOpacity = isCentered ? 1.0 : 0.0;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (isCentered) {
              onTap();
            } else {
              onFocus();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: cs.outlineVariant, width: 2.5),
            ),
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: textOpacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.primary, width: 2),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 32,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Add Task',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to create a new task',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6),
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

class _DecorCard extends StatelessWidget {
  final IconData icon;
  const _DecorCard({required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Icon(icon, color: cs.primary.withValues(alpha: 0.3), size: 48),
      ),
    );
  }
}
