import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:intl/intl.dart';
import '../services/journal_service.dart';
import '../features/mood/emotion_screen.dart';
import '../features/mood/emotion_theme.dart';

class JournalBottomSheet extends StatefulWidget {
  final String? initialText;
  final ScrollController scrollController;

  const JournalBottomSheet({
    super.key,
    this.initialText,
    required this.scrollController,
  });

  @override
  State<JournalBottomSheet> createState() => _JournalBottomSheetState();
}

class _JournalBottomSheetState extends State<JournalBottomSheet>
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  final FocusNode _textFocus = FocusNode();
  late String _journalId;
  bool _hasWrittenContent = false;

  List<String> _suggestions = [];
  bool _showSuggestions = true;

  final ScrollController _suggestionsScrollCtrl = ScrollController();

  late AnimationController _dismissCtrl;

  // Morph state
  late AnimationController _morphCtrl;
  late Animation<double> _morphAnim;
  bool _morphing = false;
  bool _showMood = false;
  double _moodSliderValue = 0.5;

  @override
  void initState() {
    super.initState();
    _journalId = DateTime.now().toIso8601String();
    _controller = TextEditingController(text: widget.initialText ?? '');
    if (widget.initialText != null && widget.initialText!.trim().isNotEmpty) {
      _hasWrittenContent = true;
    }

    if (widget.initialText == null || widget.initialText!.isEmpty) {
      JournalService.loadTodayJournal().then((existing) {
        if (existing != null && mounted) {
          setState(() {
            _journalId = existing['id']!;
            _controller.text = existing['text']!;
            if (_controller.text.trim().isNotEmpty) _hasWrittenContent = true;
          });
        }
      });
    }

    _suggestions = _generateSuggestions();

    _dismissCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _dismissCtrl.addListener(() {
      if (_dismissCtrl.isCompleted) {
        setState(() => _showSuggestions = false);
      }
    });

    _morphCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _morphAnim = CurvedAnimation(parent: _morphCtrl, curve: Curves.easeInOutBack);
    _morphCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showMood = true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFocus.requestFocus();
    });
  }

  List<String> _generateSuggestions() {
    final now = DateTime.now();
    final hour = now.hour;
    final weekday = now.weekday;
    final random = Random(now.day + now.month);

    final timeContext = hour < 12 ? 'morning' : (hour < 17 ? 'afternoon' : 'evening');

    final templates = <String>[
      "What's on your mind this $timeContext?",
      "Describe one moment that defined your day today",
      "What's a small win you had recently?",
      "Write about something you're grateful for right now",
      "What challenge is on your heart today?",
      "If your soul could speak, what would it say?",
      "What did you learn about yourself today?",
      "Describe a memory that brings you peace",
      "What made you feel alive in the last 24 hours?",
      "What's something you'd tell your younger self?",
      "How is your iman feeling today?",
      "What dua has been on your lips lately?",
      "Reflect on a verse or hadith that stayed with you",
      "What's one thing you want to let go of?",
      "Write a letter to Allah about your hopes",
      "What's a habit you're working on?",
      "Describe someone who inspired you recently",
      "What does your heart need right now?",
      "What made you smile today?",
      "If today had a title, what would it be?",
    ];

    final morningSpecific = [
      "What intention are you setting for today?",
      "How did you feel when you woke up this morning?",
      "What's one thing you want to accomplish today?",
      "What's your morning dua today?",
    ];

    final eveningSpecific = [
      "How was your day? Walk me through it",
      "What's something you'd do differently today?",
      "What's on your mind before you sleep?",
      "Reflect on three good things from today",
    ];

    final weekendSpecific = [
      "How was your weekend? Any reflections?",
      "What did you do to recharge this week?",
      "Any goals for the week ahead?",
      "What's something you've been putting off?",
    ];

    if (weekday == 6 || weekday == 7) {
      templates.addAll(weekendSpecific);
    }

    if (hour < 12) {
      templates.addAll(morningSpecific);
    } else if (hour > 18) {
      templates.addAll(eveningSpecific);
    }

    templates.shuffle(random);
    return templates.take(8).toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textFocus.dispose();
    _dismissCtrl.dispose();
    _suggestionsScrollCtrl.dispose();
    _morphCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.trim().isNotEmpty) _hasWrittenContent = true;
    JournalService.saveLocalJournalWithId(_journalId, text);
  }

  void _selectSuggestion(int index, String suggestion) {
    final current = _controller.text;
    if (current.isEmpty) {
      _controller.text = suggestion;
    } else {
      _controller.text = '$current\n$suggestion';
    }
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    _onTextChanged(_controller.text);
  }

  void _fireConfetti(BuildContext chipContext) {
    final box = chipContext.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final size = box.size;
      final pos = box.localToGlobal(Offset(size.width / 2, size.height / 2));
      final screenSize = MediaQuery.of(chipContext).size;
      Confetti.launch(
        chipContext,
        options: ConfettiOptions(
          particleCount: 18,
          spread: 360,
          angle: 90,
          x: pos.dx / screenSize.width,
          y: pos.dy / screenSize.height,
          startVelocity: 7,
          gravity: 0,
          decay: 0.98,
          scalar: 0.6,
          ticks: 20,
          colors: const [
            Colors.amber,
            Colors.orange,
            Colors.yellow,
            Colors.white,
          ],
        ),
      );
    }
  }

  void _onChipPressed(int index, BuildContext chipContext) {
    HapticFeedback.lightImpact();
    _fireConfetti(chipContext);
    final suggestion = _suggestions[index];
    setState(() => _suggestions.removeAt(index));
    _selectSuggestion(index, suggestion);
  }

  void _startMorph() {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    JournalService.saveLocalJournalWithId(_journalId, _controller.text);
    setState(() => _morphing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _morphCtrl.forward();
    });
  }

  void _onMoodSliderChanged(double v) {
    HapticFeedback.selectionClick();
    setState(() => _moodSliderValue = v);
  }

  void _onMoodDone() {
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop(
      EmotionEntry(value: _moodSliderValue, timestamp: DateTime.now()),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Build helpers
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHandle(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildTopBar(TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Text(
            DateFormat('d MMMM').format(DateTime.now()),
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFF5F5F0),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFFF5F5F0),
            ),
            onPressed: _startMorph,
            style: IconButton.styleFrom(backgroundColor: Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: TextField(
        focusNode: _textFocus,
        controller: _controller,
        onChanged: _onTextChanged,
        autofocus: false,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(fontSize: 18, color: cs.onSurface, height: 1.6),
        decoration: InputDecoration(
          hintText: "Write your thoughts, struggles, or gratitude here...",
          hintStyle: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6),
            fontSize: 18,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSuggestionsSection(ColorScheme cs, TextTheme tt, double bottomInset) {
    if (_suggestions.isEmpty) return _buildAutoSaveText(tt);
    if (!_showSuggestions && !_dismissCtrl.isAnimating) return _buildAutoSaveText(tt);

    final content = Container(
      padding: EdgeInsets.fromLTRB(16, bottomInset > 0 ? 4 : 12, 16, bottomInset > 0 ? 4 : 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.6),
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bottomInset == 0) ...[
            Text('AI suggestions', style: tt.labelMedium),
            const SizedBox(height: 10),
          ],
          if (bottomInset > 0 && _showSuggestions)
            SizedBox(
              height: 28,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.separated(
                      controller: _suggestionsScrollCtrl,
                      scrollDirection: Axis.horizontal,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) => Builder(
                        builder: (chipContext) => ActionChip(
                          label: Text(
                            _suggestions[i],
                            style: tt.labelSmall?.copyWith(color: const Color(0xFFF5F5F0)),
                          ),
                          onPressed: () => _onChipPressed(i, chipContext),
                          backgroundColor: cs.surfaceContainerHigh,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Material(
                      color: cs.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => _dismissCtrl.forward(),
                        child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFF5F5F0)),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: List.generate(_suggestions.length, (i) => Builder(
                builder: (chipContext) => ActionChip(
                  label: Text(
                    _suggestions[i],
                    style: tt.labelSmall?.copyWith(color: const Color(0xFFF5F5F0)),
                  ),
                  onPressed: () => _onChipPressed(i, chipContext),
                  backgroundColor: cs.surfaceContainerHigh,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              )),
            ),
          const SizedBox(height: 6),
          Center(child: _buildAutoSaveText(tt)),
        ],
      ),
    );

    if (_dismissCtrl.isAnimating) {
      return ClipRect(
        child: content.animate(controller: _dismissCtrl)
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1, 0),
            alignment: Alignment.bottomCenter,
            curve: Curves.easeInBack,
          )
          .fadeOut(curve: Curves.easeIn),
      );
    }
    return content;
  }

  Widget _buildAutoSaveText(TextTheme tt) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        'Journal auto saved',
        textAlign: TextAlign.center,
        style: tt.labelSmall?.copyWith(
          color: tt.labelSmall?.color?.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildMoodMode() {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(
          EmotionEntry(value: _moodSliderValue, timestamp: DateTime.now()),
        );
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
              ),
              child: SafeArea(
                bottom: true,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return MoodPanel(
                      sliderValue: _moodSliderValue,
                      onSliderChanged: _onMoodSliderChanged,
                      onDone: _onMoodDone,
                      availableHeight: constraints.maxHeight,
                      sheetWidth: size.width,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // ── Mood mode (after morph completes) ──────────────────────────────
    if (_showMood) {
      return _buildMoodMode();
    }

    // ── Morphing mode ──────────────────────────────────────────────────
    if (_morphing) {
      final size = MediaQuery.of(context).size;
      final bottomPadding = MediaQuery.of(context).padding.bottom;
      final targetMoodH = (size.height * 0.38).clamp(310.0, 370.0) + bottomPadding;

      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
              ),
              child: AnimatedBuilder(
                animation: _morphAnim,
                builder: (context, _) {
                  final t = _morphAnim.value;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRect(
                          child: Opacity(
                            opacity: (1.0 - t).clamp(0.0, 1.0),
                            child: Transform(
                              alignment: Alignment.bottomCenter,
                              transform: Matrix4.diagonal3Values(
                                1.0 - t * 0.25,
                                1.0 - t * 0.25,
                                1.0,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildHandle(cs),
                                  _buildTopBar(tt),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: _buildTextField(cs),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      Positioned.fill(
                        child: ClipRect(
                          child: Opacity(
                            opacity: t.clamp(0.0, 1.0),
                            child: Transform(
                              alignment: Alignment.topCenter,
                              transform: Matrix4.diagonal3Values(
                                0.75 + t * 0.25,
                                0.75 + t * 0.25,
                                1.0,
                              ),
                              child: IgnorePointer(
                                child: MoodPanel(
                                  sliderValue: _moodSliderValue,
                                  onSliderChanged: _onMoodSliderChanged,
                                  onDone: _onMoodDone,
                                  availableHeight: targetMoodH - bottomPadding,
                                  sheetWidth: size.width,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    // ── Normal journal mode ────────────────────────────────────────────
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.08),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
            ),
            child: PopScope(
              canPop: false,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) return;
                if (_hasWrittenContent) {
                  JournalService.saveLocalJournalWithId(_journalId, _controller.text);
                }
                Navigator.pop(context, _hasWrittenContent ? 'saved' : null);
              },
              child: CustomScrollView(
                controller: widget.scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHandle(cs),
                        _buildTopBar(tt),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomInset),
                      child: Column(
                        children: [
                          Expanded(child: _buildTextField(cs)),
                          _buildSuggestionsSection(cs, tt, bottomInset),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
