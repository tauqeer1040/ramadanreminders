import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:translator/translator.dart';
import 'package:confetti/confetti.dart';
import '../services/dhikr_service.dart';

class DhikrItem {
  final String id, name, arabic;
  final int target;
  int count;

  DhikrItem({
    required this.id,
    required this.name,
    required this.arabic,
    required this.target,
    this.count = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'arabic': arabic,
    'target': target,
    'count': count,
  };

  factory DhikrItem.fromJson(Map<String, dynamic> json) => DhikrItem(
    id: json['id'] as String,
    name: json['name'] as String,
    arabic: json['arabic'] as String,
    target: json['target'] as int,
    count: json['count'] as int? ?? 0,
  );
}

class TasbihScreen extends StatefulWidget {
  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen> {
  final DhikrService _service = DhikrService();
  List<DhikrItem> dhikrList = [];
  bool _isLoading = true;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    _loadDhikrs();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadDhikrs() async {
    final loaded = await _service.loadDhikrs();
    if (mounted) {
      if (loaded != null && loaded.isNotEmpty) {
        setState(() {
          dhikrList = loaded;
          _isLoading = false;
        });
      } else {
        setState(() {
          dhikrList = [
            DhikrItem(
              id: "subhan",
              name: "SubhanAllah",
              arabic: "سُبْحَانَ اللّٰهِ",
              target: 33,
            ),
            DhikrItem(
              id: "alhamd",
              name: "Alhamdulillah",
              arabic: "الْحَمْدُ لِلّٰهِ",
              target: 33,
            ),
            DhikrItem(
              id: "allahu",
              name: "Allahu Akbar",
              arabic: "اللّٰهُ أَكْبَرُ",
              target: 34,
            ),
          ];
          _isLoading = false;
        });
        _service.saveDhikrs(dhikrList);
      }
    }
  }

  void _saveList() {
    _service.saveDhikrs(dhikrList);
  }

  void increment(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      if (dhikrList[index].count < dhikrList[index].target) {
        dhikrList[index].count++;
        if (dhikrList[index].count == dhikrList[index].target) {
          HapticFeedback.heavyImpact();
          _confettiController.play();
        }
      }
    });
    _saveList();
  }

  void decrement(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      if (dhikrList[index].count > 0) {
        dhikrList[index].count--;
      }
    });
    _saveList();
  }

  void reset(int index) {
    HapticFeedback.mediumImpact();
    setState(() => dhikrList[index].count = 0);
    _saveList();
  }

  Future<void> _showDhikrDialog({DhikrItem? item, int? index}) async {
    HapticFeedback.lightImpact();
    final nameController = TextEditingController(text: item?.name ?? '');
    final targetController = TextEditingController(
      text: item?.target.toString() ?? '33',
    );

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(item == null ? 'Add Tasbih' : 'Edit Tasbih'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name (e.g. SubhanAllah)',
                  ),
                ),
                TextField(
                  controller: targetController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Target Count'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final name = nameController.text.trim();
      final target = int.tryParse(targetController.text) ?? 33;

      if (name.isNotEmpty) {
        setState(() {
          _isLoading = true;
        });

        String arabicText = item?.arabic ?? '';

        // Auto-translate to Arabic if it's a new item or name changed
        if (item == null || item.name != name) {
          try {
            final translator = GoogleTranslator();
            final translation = await translator.translate(name, to: 'ar');
            arabicText = translation.text;
          } catch (e) {
            arabicText = name; // Fallback to english if translation fails
          }
        }

        if (!mounted) return;

        setState(() {
          if (item == null) {
            dhikrList.add(
              DhikrItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                arabic: arabicText,
                target: target,
              ),
            );
          } else if (index != null) {
            dhikrList[index] = DhikrItem(
              id: item.id,
              name: name,
              arabic: arabicText,
              target: target,
              count: item.count > target ? target : item.count,
            );
          }
          _isLoading = false;
        });
        _saveList();
      }
    }
  }

  void _deleteDhikr(int index) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tasbih'),
        content: const Text('Are you sure you want to delete this Tasbih?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                dhikrList.removeAt(index);
              });
              _saveList();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final total = dhikrList.fold(0, (sum, d) => sum + d.count);
    final totalTarget = dhikrList.fold(0, (sum, d) => sum + d.target);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          "Tasbih Counter",
          style: textTheme.titleLarge?.copyWith(color: colorScheme.primary),
        ),
        backgroundColor: Colors.transparent,
        actions: [
          BouncingWidget(
            onPressed: () => _showDhikrDialog(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Icon(Icons.add, size: 26),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                "$total/$totalTarget  ",
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dhikrList.length,
                  itemBuilder: (context, index) {
                    final d = dhikrList[index];
                    final isComplete = d.count >= d.target;

                    return BouncingWidget(
                      onPressed: isComplete ? null : () => increment(index),
                      child: Card(
                        color: isComplete
                            ? colorScheme.secondaryContainer.withValues(
                                alpha: 0.5,
                              )
                            : colorScheme.surfaceContainer,
                        margin: const EdgeInsets.only(bottom: 16),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.arabic,
                                        style: TextStyle(
                                          fontSize: 22,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      Text(
                                        d.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        style: IconButton.styleFrom(
                                          backgroundColor:
                                              colorScheme.secondaryContainer,
                                          foregroundColor:
                                              colorScheme.onSecondaryContainer,
                                        ),
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 20,
                                        ),
                                        onPressed: () => reset(index),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        onSelected: (value) {
                                          if (value == 'edit') {
                                            _showDhikrDialog(
                                              item: d,
                                              index: index,
                                            );
                                          } else if (value == 'delete') {
                                            _deleteDhikr(index);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                tween: Tween<double>(
                                  begin: 0,
                                  end: d.count / d.target,
                                ),
                                builder: (context, value, _) =>
                                    LinearProgressIndicator(
                                      value: value,
                                      backgroundColor:
                                          colorScheme.surfaceContainerHighest,
                                      color: isComplete
                                          ? colorScheme.secondary
                                          : colorScheme.primary,
                                    ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  BouncingWidget(
                                    onPressed: () => decrement(index),
                                    child: FloatingActionButton.small(
                                      heroTag: "dec$index",
                                      onPressed: () {},
                                      backgroundColor: colorScheme.secondary,
                                      foregroundColor: colorScheme.onSecondary,
                                      elevation: 0,
                                      child: const Icon(Icons.remove),
                                    ),
                                  ),
                                  Text(
                                    "${d.count}",
                                    style: TextStyle(
                                      fontSize: 36,
                                      color: isComplete
                                          ? colorScheme.secondary
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                  BouncingWidget(
                                    onPressed: isComplete
                                        ? null
                                        : () => increment(index),
                                    child: FloatingActionButton(
                                      heroTag: "inc$index",
                                      onPressed: isComplete ? null : () {},
                                      backgroundColor: isComplete
                                          ? colorScheme.surfaceContainerHighest
                                          : colorScheme.primary,
                                      foregroundColor: isComplete
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.onPrimary,
                                      elevation: isComplete ? 0 : 4,
                                      child: const Icon(Icons.add, size: 28),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: [
                colorScheme.primary,
                colorScheme.secondary,
                colorScheme.tertiary,
              ], // Use theme colors for confetti
            ),
          ),
        ],
      ),
    );
  }
}

class BouncingWidget extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const BouncingWidget({super.key, required this.child, this.onPressed});

  @override
  State<BouncingWidget> createState() => _BouncingWidgetState();
}

class _BouncingWidgetState extends State<BouncingWidget> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null) setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null) {
      setState(() => _isPressed = false);
      widget.onPressed?.call();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null) setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        scale: _isPressed ? 0.90 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: _isPressed ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}
