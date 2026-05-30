import 'package:flutter/material.dart';
import 'widgets/streak_graph.dart';
import '../services/streak_service.dart';

class StreakProfileCard extends StatefulWidget {
  const StreakProfileCard({super.key});

  @override
  State<StreakProfileCard> createState() => _StreakProfileCardState();
}

class _StreakProfileCardState extends State<StreakProfileCard> {
  int _streak = 1;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final streak = await StreakService.getStreak();
    if (mounted) setState(() { _streak = streak; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: StreakGraph(streak: _streak),
    );
  }
}
