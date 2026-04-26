import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../models/bullet_item.dart';
import '../services/journal_service.dart';
import 'task_card.dart';

/// Horizontal carousel of daily tasks, shown on the homepage.
///
/// Loads/saves tasks via [JournalService] (date-keyed SharedPreferences).
/// Seeds 3 defaults if no tasks exist for today.
class TaskCarousel extends StatefulWidget {
  const TaskCarousel({super.key});

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
  List<String> _imageRotation = [];
  int _imageRotationIndex = 0;

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
    // 1. Pre-load available images for immediate rendering
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestJson);
      _availableImages = manifestMap.keys
          .where(
            (key) =>
                key.startsWith('assets/photos/images/') &&
                (key.toLowerCase().endsWith('.jpeg') ||
                    key.toLowerCase().endsWith('.jpg') ||
                    key.toLowerCase().endsWith('.png')),
          )
          .toList()
        ..sort();
    } catch (_) {
      _availableImages = [
        'assets/photos/images/Delicate Translucent Flower.png',
        'assets/photos/images/ethreialbloom1.jpeg',
        'assets/photos/images/EtherealFlower.jpeg',
        'assets/photos/images/DelicateOrangeFlowerinBloom.jpeg',
        'assets/photos/images/EtherealFlower-1-.jpeg',
        'assets/photos/images/Ethereal Flower in Motion.png',
        'assets/photos/images/Ethereal Flower(1).png',
        'assets/photos/images/Ethereal Flower.png',
        'assets/photos/images/Ethereal Glowing Flower.png',
        'assets/photos/images/Ethereal Translucent Flower.png',
        'assets/photos/images/Radiant Flower Glow.png',
        'assets/photos/images/Z5u14ZbqstJ9-Dkw_EtherealFlower-1-.jpeg',
      ];
    }

    // 2. Instant Load from Cache
    var cachedTasks = await _service.loadJournalTasks(_todayKey);
    if (cachedTasks.isNotEmpty) {
      _assignImages(cachedTasks);
      if (mounted) {
        setState(() {
          _tasks = cachedTasks;
          _loading = false;
        });
      }
    }

    // 3. Silent/Background Fetch from Server
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final aiTasks = await _service.fetchLatestAIDrivenTasks(user.uid);
      
      if (aiTasks.isNotEmpty) {
        _assignImages(aiTasks);
        if (mounted) {
          setState(() {
            _tasks = aiTasks;
            _loading = false;
          });
        }
      }
    }

    // 4. Final Fallback if still empty (first time install)
    if (_tasks.isEmpty) {
      final defaults = _defaultTasks();
      _assignImages(defaults);
      await _service.saveJournalTasks(_todayKey, defaults);
      if (mounted) {
        setState(() {
          _tasks = defaults;
          _loading = false;
        });
      }
    }
  }

  void _resetImageRotation() {
    if (_availableImages.isEmpty) {
      _imageRotation = ['assets/photos/images/ethreialbloom1.jpeg'];
      _imageRotationIndex = 0;
      return;
    }

    _imageRotation = List<String>.from(_availableImages)..shuffle(_random);
    _imageRotationIndex = 0;
  }

  String _nextImage() {
    if (_imageRotation.isEmpty || _imageRotationIndex >= _imageRotation.length) {
      _resetImageRotation();
    }
    final image = _imageRotation[_imageRotationIndex];
    _imageRotationIndex += 1;
    return image;
  }

  void _assignImages(List<BulletItem> tasks) {
    _resetImageRotation();
    for (final task in tasks) {
      task.bgImage = _nextImage();
    }
  }

  List<BulletItem> _defaultTasks() => [
    BulletItem(
      id: 'default_1',
      content: 'Compliment a friend',
      bgImage: 'assets/photos/images/ethreialbloom1.jpeg',
      difficulty: 'easy',
    ),
    BulletItem(
      id: 'default_2',
      content: 'Read an Aayah of the Quran ',
      bgImage: 'assets/photos/images/EtherealFlower.jpeg',
      difficulty: 'mid',
    ),
    BulletItem(
      id: 'default_3',
      content: 'Give Charity',
      bgImage: 'assets/photos/images/DelicateOrangeFlowerinBloom.jpeg',
      difficulty: 'hard',
    ),
  ];

  void _toggle(int index) {
    final newState = !_tasks[index].completed;
    setState(() => _tasks[index].completed = newState);
    _service.saveJournalTasks(_todayKey, _tasks);

    if (newState) {
      HapticFeedback.heavyImpact();
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
            bgImage: _nextImage(),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
       return Skeletonizer(
         enabled: true,
         child: CarouselView.weighted(
           controller: _carouselController,
           flexWeights: const <int>[5, 1],
           itemSnapping: true,
           children: [
             for (int i = 0; i < 3; i++)
               TaskCard(
                 text: 'Loading AI suggested task content...',
                 completed: false,
                 isFocused: i == 0,
                 bgImage: 'assets/photos/images/ethreialbloom1.jpeg',
                 onDelete: () {},
                 index: i,
               ),
           ],
         ),
       );
    }

    return CarouselView.weighted(
      controller: _carouselController,
      flexWeights: const <int>[5, 1],
      itemSnapping: true,
      onTap: (tappedIndex) {
        if (tappedIndex < _tasks.length) {
          if (_focusedIndex != tappedIndex) {
            setState(() => _focusedIndex = tappedIndex);
            _carouselController.animateToItem(
              tappedIndex,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
            );
          }
          _toggle(tappedIndex);
        } else if (tappedIndex == _tasks.length) {
          if (_focusedIndex != _tasks.length) {
            setState(() => _focusedIndex = _tasks.length);
            _carouselController.animateToItem(
              _tasks.length,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          } else {
            _showAddTaskDialog();
          }
        }
      },
      children: [
        for (int i = 0; i < _tasks.length; i++)
          TaskCard(
            key: ValueKey(_tasks[i].id),
            text: _tasks[i].content,
            completed: _tasks[i].completed,
            isFocused: i == _focusedIndex,
            bgImage: _tasks[i].bgImage ?? _nextImage(),
            onDelete: () => _delete(i),
            index: i,
          ),
        _AddTaskCard(
          onTap: () async {
            // Unused directly inside AddTaskCard now,
            // since CarouselView intercepts the tap natively.
          },
        ),
      ],
    );
  }
}

class _AddTaskCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTaskCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCentered = constraints.maxWidth > 160;
        final double textOpacity = isCentered ? 1.0 : 0.0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            // onTap: onTap,
            borderRadius: BorderRadius.circular(32),
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
          ),
        );
      },
    );
  }
}
