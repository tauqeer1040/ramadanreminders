import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../../theme/app_theme.dart';
import 'duo_button.dart';
import '../journal_bottom_sheet.dart';
import 'star_trail_widget.dart';
import '../../services/star_service.dart';

class JournalEntryButton extends StatefulWidget {
  final String displayName;
  final GlobalKey starBadgeKey;
  final ValueChanged<String?>? onJournalSaved;

  const JournalEntryButton({
    super.key,
    required this.displayName,
    required this.starBadgeKey,
    this.onJournalSaved,
  });

  @override
  State<JournalEntryButton> createState() => JournalEntryButtonState();
}

class JournalEntryButtonState extends State<JournalEntryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _trailController;
  bool _showStarTrail = false;
  Offset? _trailStart, _trailEnd;
  final _writeBtnKey = GlobalKey();
  final _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  String? _mascotMessage;

  @override
  void initState() {
    super.initState();
    _trailController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _showStarTrail = false);
        }
      });
  }

  @override
  void dispose() {
    _trailController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String? get lastMascotMessage => _mascotMessage;

  Future<void> _onJournalSaved(double moodValue) async {
    HapticFeedback.mediumImpact();

    final startCtx = _writeBtnKey.currentContext;
    final endCtx = widget.starBadgeKey.currentContext;
    if (startCtx != null && endCtx != null && mounted) {
      final startBox = startCtx.findRenderObject() as RenderBox;
      final endBox = endCtx.findRenderObject() as RenderBox;
      _trailStart = startBox.localToGlobal(startBox.size.center(Offset.zero));
      _trailEnd = endBox.localToGlobal(endBox.size.center(Offset.zero));
      setState(() => _showStarTrail = true);
      _trailController.forward(from: 0);
    }

    await StarService.tryIncrement(10, 'last_journal_star_time');

    if (moodValue >= 0.60) {
      _confettiController.play();
    }

    if (mounted) {
      const templates = [
        "Diary saved! Come back tomorrow morning to read your AI insights, {name}.",
        "Diary saved! I'll start making your Personal AI insights, {name}!",
        "Diary saved! Your entry is safe with me. I'll prepare your AI insights for tomorrow morning, {name}.",
        "Diary saved! Beautiful reflection, {name}! Check back tomorrow morning for your AI insights.",
        "Diary saved! Time to analyze your mood and write down some sweet insights for you tomorrow morning, {name}."
      ];
      final msg = templates[Random().nextInt(templates.length)].replaceAll('{name}', widget.displayName);
      setState(() => _mascotMessage = msg);
      widget.onJournalSaved?.call(msg);
    }
  }

  Future<void> showEditor(BuildContext context) async {
    if (!context.mounted) return;

    final wroteResult = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => JournalBottomSheet(scrollController: scrollCtrl),
      ),
    );
    if (wroteResult is double) {
      await _onJournalSaved(wroteResult);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DuoButton(
          key: _writeBtnKey,
          onPressed: () => showEditor(context),
          backgroundColor: AppTheme.neonPurple,
          depthColor: AppTheme.neonPurple.withValues(alpha: 0.7),
          radius: 20,
          height: 72,
          sfxType: DuoSfxType.positive,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_rounded, color: AppTheme.starWhite, size: 22),
              const SizedBox(width: 10),
              Text(
                'Write',
                style: TextStyle(
                  color: AppTheme.starWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        IgnorePointer(
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 8,
            emissionFrequency: 0.02,
            maxBlastForce: 35,
            minBlastForce: 10,
            colors: const [
              Colors.blue, Colors.pink, Colors.yellow, Colors.green,
            ],
          ),
        ),
        if (_showStarTrail && _trailStart != null && _trailEnd != null)
          IgnorePointer(
            child: StarTrailWidget(
              start: _trailStart!,
              end: _trailEnd!,
              controller: _trailController,
            ),
          ),
      ],
    );
  }
}
