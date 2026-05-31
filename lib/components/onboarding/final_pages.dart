import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:scratcher/scratcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_confetti/flutter_confetti.dart' as fc;
import 'package:in_app_review/in_app_review.dart';
import '../../services/analogy_service.dart';
import '../../services/journal_service.dart';
import 'onboarding_data.dart';
import '../widgets/duo_button.dart';
import '../../theme/app_theme.dart';
import '../widgets/streak_graph.dart';

class FirstJournalPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const FirstJournalPage({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  State<FirstJournalPage> createState() => _FirstJournalPageState();
}

class _FirstJournalPageState extends State<FirstJournalPage> {
  final _controller = TextEditingController();
  final _journalService = JournalService();
  final _focusNode = FocusNode();
  bool _saving = false;
  final _suggestionsKey = GlobalKey<AnimatedListState>();
  final _suggestionsScrollController = ScrollController();
  final _mainScrollController = ScrollController();
  late List<String> _suggestions;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _suggestions = [
      "I had a good day today",
      "Gratitude:",
      "Things to improve upon",
      "Today I learned...",
      "I felt...",
      "Something that made me smile",
      "My prayer today",
      "A challenge I faced",
    ];
    if (widget.data.journalEntry != null) {
      _controller.text = widget.data.journalEntry!;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _suggestionsScrollController.dispose();
    _mainScrollController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _mainScrollController.hasClients) {
      _mainScrollController.animateTo(
        _mainScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
      );
    }
    setState(() {});
  }

  void _onTextChanged(String text) {
    widget.data.journalEntry = text;
    JournalService.saveLocalJournalWithId(
      DateTime.now().toIso8601String().split('T')[0],
      text,
    );
    setState(() {});
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
    final removed = _suggestions.removeAt(index);
    _suggestionsKey.currentState?.removeItem(
      index,
      (context, animation) => _buildSuggestionItem(removed, animation, index),
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildSuggestionItem(
    String text,
    Animation<double> animation,
    int index,
  ) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SizeTransition(
      sizeFactor: animation,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Builder(
          builder: (chipContext) {
            return ActionChip(
              label: Text(
                text,
                style: tt.labelSmall?.copyWith(color: cs.onSurface),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                final box = chipContext.findRenderObject() as RenderBox?;
                if (box != null && box.hasSize) {
                  final size = box.size;
                  final pos = box.localToGlobal(
                    Offset(size.width / 2, size.height / 2),
                  );
                  final screenSize = MediaQuery.of(chipContext).size;
                  fc.Confetti.launch(
                    chipContext,
                    options: fc.ConfettiOptions(
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
                _selectSuggestion(index, text);
              },
              backgroundColor: cs.surfaceContainerHigh,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final keyboardVisible = _focusNode.hasFocus;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final canContinue =
        _controller.text.trim().isNotEmpty || widget.data.journalEntry != null;

    final textField = TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: _onTextChanged,
      autofocus: false,
      maxLines: keyboardVisible ? null : 6,
      minLines: keyboardVisible ? null : 4,
      textCapitalization: TextCapitalization.sentences,
      style: TextStyle(fontSize: 18, color: cs.onSurface, height: 1.6),
      decoration: InputDecoration(
        hintText: "Write your thoughts, struggles, or gratitude here...",
        hintStyle: TextStyle(
          color: cs.onSurface.withValues(alpha: 0.6),
          fontSize: 18,
        ),
        filled: true,
        fillColor: cs.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.all(20),
      ),
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _mainScrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  clipBehavior: Clip.antiAlias,
                  child: AnimatedOpacity(
                    opacity: keyboardInset == 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: keyboardInset == 0
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 32),
                              Text(
                                "Your first diary",
                                style: tt.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),

                              Text(
                                "This is your private space. Nobody else will read this.",
                                style: tt.bodyLarge,
                              ),
                              const SizedBox(height: 8),

                              Text(
                                "It's completely okay to write here — whatever's on your heart.",
                                style: tt.bodyLarge,
                              ),
                              const SizedBox(height: 16),
                              GestureDetector(
                                onTap: () => _focusNode.requestFocus(),
                                child: Image.asset(
                                  'assets/photos/mascot/name.png',
                                  height: 200,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              Text(
                                "Did you know: journaling regularly reduces stress, sharpens focus, and improves sleep?",
                                style: tt.bodyLarge?.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const SizedBox(height: 16),
                            ],
                          )
                        : const SizedBox(width: double.infinity, height: 24),
                  ),
                ),
                textField,
                const SizedBox(height: 12),
                Text(
                  'Prompt ideas',
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: AnimatedList(
                    key: _suggestionsKey,
                    scrollDirection: Axis.horizontal,
                    controller: _suggestionsScrollController,
                    initialItemCount: _suggestions.length,
                    itemBuilder: (context, i, animation) =>
                        _buildSuggestionItem(_suggestions[i], animation, i),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          clipBehavior: Clip.antiAlias,
          child: AnimatedOpacity(
            opacity: keyboardInset == 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: keyboardInset == 0
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                    child: _saving
                        ? const Center(child: CircularProgressIndicator())
                        : Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: DuoButton(
                                  onPressed: widget.onBack,
                                  backgroundColor: cs.secondaryContainer,
                                  depthColor: cs.secondaryContainer.withValues(
                                    alpha: 0.8,
                                  ),
                                  radius: 16,
                                  child: Text(
                                    "Back",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: DuoButton(
                                  onPressed: canContinue ? _handleSave : null,
                                  backgroundColor: cs.primary,
                                  depthColor: cs.primary.withValues(alpha: 0.8),
                                  radius: 16,
                                  dimOnDisabled: true,
                                  child: Text(
                                    "Save & Continue",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave() async {
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final text = _controller.text.trim();
    widget.data.journalEntry = text;
    if (text.isNotEmpty) {
      final dateKey = DateTime.now().toIso8601String().split('T')[0];
      await _journalService.saveJournalGratitude(dateKey, text);
    }
    if (mounted) {
      setState(() => _saving = false);
      widget.onNext();
    }
  }
}

class AiInsightPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final void Function(int amount)? onStarsEarned;

  const AiInsightPage({
    required this.data,
    required this.onNext,
    required this.onBack,
    this.onStarsEarned,
    super.key,
  });

  @override
  State<AiInsightPage> createState() => _AiInsightPageState();
}

class _AiInsightPageState extends State<AiInsightPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  double _progress = 0;
  AnimationController? _loadingController;
  bool _apiDone = false;
  bool _animationDone = false;
  final CardSwiperController _swiperController = CardSwiperController();
  List<_JournalCard> _cards = [];
  int _swipedCount = 0;
  final Set<int> _revealedCards = {};
  List<String> _scratchCardImages = [];

  @override
  void initState() {
    super.initState();
    _initScratchImages();

    final entry = widget.data.journalEntry;
    final cachedAnalogies = widget.data.journalAnalogies;
    final lastEntry = widget.data.lastGeneratedJournalEntry;

    final hasCache =
        entry != null &&
        entry.trim().isNotEmpty &&
        cachedAnalogies.isNotEmpty &&
        lastEntry == entry;

    if (hasCache) {
      _loading = false;
      _progress = 1.0;
      _apiDone = true;
      _animationDone = true;
      _generateCards(skipLoading: true);
    } else {
      _loading = true;
      _progress = 0.0;
      _apiDone = false;
      _animationDone = false;

      _loadingController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 3),
      );

      _loadingController!.addListener(() {
        if (mounted) {
          setState(() {
            _progress = _loadingController!.value;
          });
        }
      });

      _loadingController!.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _animationDone = true;
          _checkLoadingFinished();
        }
      });

      _loadingController!.forward();
      _generateCards(skipLoading: false);
    }
  }

  void _initScratchImages() {
    final images = [
      'assets/photos/images/scratchCards/scratch.jpg',
      'assets/photos/images/scratchCards/scratch (2).jpg',
      'assets/photos/images/scratchCards/scratch (3).jpg',
      'assets/photos/images/scratchCards/scratch (4).jpg',
      'assets/photos/images/scratchCards/scratch (5).jpg',
      'assets/photos/images/scratchCards/scratch (6).jpg',
      'assets/photos/images/scratchCards/scratch (7).jpg',
      'assets/photos/images/scratchCards/scratch (8).jpg',
      'assets/photos/images/scratchCards/scratch (9).jpg',
    ];
    images.shuffle();
    _scratchCardImages = images;
  }

  @override
  void dispose() {
    _loadingController?.dispose();
    super.dispose();
  }

  void _onSwipe() {
    if (_swipedCount >= 3) return;
    _swipedCount++;
    widget.onStarsEarned?.call(20);
  }

  void _triggerConfetti() {
    final colors = [
      const Color(0xFFD6DF7E), // Lime
      const Color(0xFFFAA49A), // Pink
      const Color(0xFF0052FF), // Electric Blue
      Colors.amber,
      Colors.orange,
      Colors.white,
    ];
    // Left burst
    fc.Confetti.launch(
      context,
      options: fc.ConfettiOptions(
        particleCount: 35,
        angle: 60,
        spread: 55,
        x: 0,
        y: 0.6,
        colors: colors,
      ),
    );
    // Right burst
    fc.Confetti.launch(
      context,
      options: fc.ConfettiOptions(
        particleCount: 35,
        angle: 120,
        spread: 55,
        x: 1,
        y: 0.6,
        colors: colors,
      ),
    );
  }

  void _checkLoadingFinished() {
    if (_apiDone && _animationDone) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _generateCards({bool skipLoading = false}) async {
    final entry = widget.data.journalEntry;
    if (entry == null || entry.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _apiDone = true;
          _animationDone = true;
        });
      }
      return;
    }

    List<String> result;
    if (skipLoading) {
      result = widget.data.journalAnalogies;
    } else {
      result = await AnalogyService.generateJournalAnalogies(entry);
      widget.data.journalAnalogies = result;
      widget.data.lastGeneratedJournalEntry = entry;
    }

    if (!mounted) return;
    setState(() {
      _cards = [
        _JournalCard(
          icon: Icons.menu_book_rounded,
          title: 'A Surah for You',
          content: result.isNotEmpty ? result[0] : _fallbackSurah,
        ),
        _JournalCard(
          icon: Icons.auto_awesome_rounded,
          title: 'An Ayah to Hold Onto',
          content: result.length > 1 ? result[1] : _fallbackAyah,
        ),
        _JournalCard(
          icon: Icons.wb_sunny_rounded,
          title: 'A Story to Remember',
          content: result.length > 2 ? result[2] : _fallbackStory,
        ),
      ];
      _apiDone = true;
    });

    if (!skipLoading) {
      _checkLoadingFinished();
    }
  }

  String get _fallbackSurah =>
      'Your journey mirrors Surah Ad-Duha — after every night comes the morning light. '
      'Allah never abandoned you, and what lies ahead is far greater than what has passed. '
      '— Quran 93:1-5';

  String get _fallbackAyah =>
      '"And He found you lost and guided you." '
      'Every step you take toward Him, He runs toward you. '
      'Your reflection today is proof that He has already placed a light in your heart. '
      '— Quran 93:7';

  String get _fallbackStory =>
      'Like the Companion who came to the Prophet ﷺ with a heavy heart, '
      'you too have chosen to speak your truth. The Prophet ﷺ said: '
      '"There is no Muslim who calls upon Allah with a supplication, '
      'except that Allah grants him what he asks or protects him from an equivalent evil." '
      '— Tirmidhi';

  String _stripVerses(String text) {
    return text
        .replaceAll(
          RegExp(r'— (Quran \d+:\d+|Tirmidhi|Bukhari|Muslim|Ahmad)'),
          '',
        )
        .trim();
  }

  List<Widget> _extractPills(String text, Color textCol, Color bgCol) {
    final regex = RegExp(r'— (Quran \d+:\d+|Tirmidhi|Bukhari|Muslim|Ahmad)');
    final matches = regex.allMatches(text);
    if (matches.isEmpty) return [];
    return [
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: matches.map((m) {
          final verse = m.group(1)!;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: bgCol,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: textCol.withOpacity(0.2)),
            ),
            child: Text(
              verse,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textCol,
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }

  String _getLoadingText(double progress) {
    if (progress < 0.25) {
      return "Reading the Holy Quran for insights...";
    } else if (progress < 0.50) {
      return "Searching ancient wisdom and Tafsir...";
    } else if (progress < 0.75) {
      return "Connecting divine verses directly to your heart...";
    } else {
      return "Almost there! Unveiling customized reflections...";
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_loading) ...[
            const Spacer(flex: 1),
            Text(
              _getLoadingText(_progress),
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 12,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "${(_progress * 100).round()}%",
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(flex: 1),
          ] else ...[
            const SizedBox(height: 24),
            Text(
              "Scratch to reveal your first insights!",
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardHeight = constraints.maxHeight;
                  return SizedBox(
                    width: MediaQuery.of(context).size.width * 0.85,
                    height: cardHeight,
                    child: Stack(
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: cardHeight,
                          child: CardSwiper(
                            controller: _swiperController,
                            cardsCount: _cards.length,
                            numberOfCardsDisplayed: 3,
                            onSwipe: (_, __, ___) {
                              _onSwipe();
                              HapticFeedback.mediumImpact();
                              return true;
                            },
                            cardBuilder: (context, index, _, __) {
                              final card = _cards[index];

                              Color cardBg;
                              Color textColor;
                              Color iconColor;
                              Color pillBg;
                              Color pillText;

                              if (index % 3 == 0) {
                                cardBg = const Color(0xFFD6DF7E); // Lime
                                textColor = const Color(
                                  0xFF13441A,
                                ); // Dark Green
                                iconColor = const Color(
                                  0xFF187B25,
                                ); // Vibrant Green
                                pillBg = const Color(
                                  0xFF187B25,
                                ).withOpacity(0.12);
                                pillText = const Color(0xFF13441A);
                              } else if (index % 3 == 1) {
                                cardBg = const Color(0xFFFAA49A); // Pink
                                textColor = const Color(
                                  0xFF4E1106,
                                ); // Dark Burgundy
                                iconColor = const Color(0xFFC4391D); // Red
                                pillBg = const Color(
                                  0xFFC4391D,
                                ).withOpacity(0.12);
                                pillText = const Color(0xFF4E1106);
                              } else {
                                cardBg = const Color(0xFFA0C4FF); // Sky Blue
                                textColor = const Color(
                                  0xFF00154F,
                                ); // Dark Navy
                                iconColor = const Color(
                                  0xFF0052FF,
                                ); // Electric Blue
                                pillBg = const Color(
                                  0xFF0052FF,
                                ).withOpacity(0.12);
                                pillText = const Color(0xFF00154F);
                              }

                              final revealed = _revealedCards.contains(index);

                              Widget cardContent = Container(
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(32),
                                  border: Border.all(
                                    color: textColor,
                                    width: 2,
                                  ),
                                ),
                                child: DefaultTextStyle(
                                  style: TextStyle(color: textColor),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            card.icon,
                                            color: iconColor,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: TextScroll(
                                              card.title,
                                              velocity: const Velocity(
                                                pixelsPerSecond: Offset(40, 0),
                                              ),
                                              mode: TextScrollMode.endless,
                                              delayBefore: const Duration(
                                                milliseconds: 500,
                                              ),
                                              style: tt.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                _stripVerses(card.content),
                                                style: tt.bodyLarge?.copyWith(
                                                  height: 1.6,
                                                  color: textColor,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              ..._extractPills(
                                                card.content,
                                                pillText,
                                                pillBg,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              if (!revealed) {
                                final scratchImage =
                                    _scratchCardImages.isNotEmpty
                                    ? _scratchCardImages[index %
                                          _scratchCardImages.length]
                                    : 'assets/photos/elements/app_bg2.webp';

                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: Stack(
                                    children: [
                                      Scratcher(
                                        brushSize: 30,
                                        threshold: 35,
                                        image: Image.asset(
                                          scratchImage,
                                          fit: BoxFit.cover,
                                        ),
                                        onThreshold: () {
                                          setState(
                                            () => _revealedCards.add(index),
                                          );
                                          HapticFeedback.heavyImpact();
                                          _triggerConfetti();
                                        },
                                        child: cardContent,
                                      ),
                                      IgnorePointer(
                                        child: Shimmer.fromColors(
                                          baseColor: Colors.transparent,
                                          highlightColor: Colors.white
                                              .withOpacity(0.25),
                                          period: const Duration(
                                            milliseconds: 2000,
                                          ),
                                          child: Container(color: Colors.black),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return cardContent;
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (!_loading)
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: DuoButton(
                    onPressed: widget.onBack,
                    backgroundColor: cs.secondaryContainer,
                    depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                    radius: 16,
                    height: 56,
                    child: Text(
                      "Back",
                      style: TextStyle(
                        fontSize: 16,
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DuoButton(
                    onPressed: widget.onNext,
                    backgroundColor: cs.primary,
                    depthColor: cs.primary.withValues(alpha: 0.8),
                    radius: 16,
                    height: 56,
                    child: Text(
                      "Continue",
                      style: TextStyle(
                        fontSize: 16,
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_loading) const SizedBox(height: 56),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _JournalCard {
  final IconData icon;
  final String title;
  final String content;
  const _JournalCard({
    required this.icon,
    required this.title,
    required this.content,
  });
}

class CelebrationPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const CelebrationPage({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  State<CelebrationPage> createState() => _CelebrationPageState();
}

class _CelebrationPageState extends State<CelebrationPage> {
  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cs = Theme.of(context).colorScheme;
      fc.Confetti.launch(
        context,
        options: fc.ConfettiOptions(
          particleCount: 100,
          spread: 360,
          y: 0.4,
          colors: [cs.primary, cs.tertiary, AppTheme.starGold],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    "Congratulations!",
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "You've completed your first reflection.",
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const StreakGraph(streak: 1, size: 130),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: DuoButton(
                          onPressed: widget.onBack,
                          backgroundColor: cs.secondaryContainer,
                          depthColor: cs.secondaryContainer.withValues(
                            alpha: 0.8,
                          ),
                          radius: 16,
                          child: Text(
                            "Back",
                            style: TextStyle(
                              fontSize: 16,
                              color: cs.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: DuoButton(
                          onPressed: widget.onNext,
                          backgroundColor: cs.primary,
                          depthColor: cs.primary.withValues(alpha: 0.8),
                          radius: 16,
                          child: Text(
                            "Continue",
                            style: TextStyle(
                              fontSize: 16,
                              color: cs.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SummaryPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const SummaryPage({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  String _formatTimeSpent(DateTime start) {
    final diff = DateTime.now().difference(start);
    final mins = (diff.inSeconds / 60.0).ceil();
    final clampedMins = mins.clamp(1, 9999);
    return "$clampedMins ${clampedMins == 1 ? 'min' : 'mins'}";
  }

  String _getSpiritualProfile(OnboardingData data) {
    final entry = data.journalEntry?.toLowerCase() ?? "";
    if (entry.isEmpty) return "Seeker of Light";

    if (entry.contains("thank") ||
        entry.contains("gratitude") ||
        entry.contains("bless") ||
        entry.contains("happy") ||
        entry.contains("smile")) {
      return "Mindful & Grateful";
    } else if (entry.contains("struggle") ||
        entry.contains("sad") ||
        entry.contains("hard") ||
        entry.contains("difficult") ||
        entry.contains("fear")) {
      return "Patient & Resilient";
    } else if (entry.contains("learn") ||
        entry.contains("read") ||
        entry.contains("quran") ||
        entry.contains("knowledge") ||
        entry.contains("understand")) {
      return "Thoughtful & Wise";
    } else if (entry.contains("pray") ||
        entry.contains("dua") ||
        entry.contains("allah") ||
        entry.contains("forgive") ||
        entry.contains("mercy")) {
      return "Humble & Devout";
    } else if (entry.contains("help") ||
        entry.contains("kind") ||
        entry.contains("family") ||
        entry.contains("others") ||
        entry.contains("love")) {
      return "Kind & Empathetic";
    }

    if (data.journalTags.isNotEmpty) {
      final firstTag = data.journalTags.first.toLowerCase();
      if (firstTag.contains("gratitude")) return "Mindful Optimist";
      if (firstTag.contains("struggle")) return "Patient Striver";
      if (firstTag.contains("prayer")) return "Devout Worshipper";
    }

    return "Sincere Believer";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.only(
                top: 24,
                left: 32,
                right: 32,
                bottom: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${data.displayName != null ? "${data.displayName}'s S" : "Your S"}piritual Profile",
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Only 12% of users reach this stage. With your first deep reflection saved, you've taken a beautiful step closer to the Holy Quran!\nAdd to that, You have achieved a highscore of 200 stars! Masha’Allah 🌟",
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildSummaryRow(
                        cs,
                        "Username",
                        data.displayName ?? "Guest",
                      ),
                      _buildSummaryRow(
                        cs,
                        "Kitty's Name",
                        data.catName ?? "Meowmin",
                      ),
                      _buildSummaryRow(
                        cs,
                        "Daily Screen Time",
                        data.phoneHours != null
                            ? "${data.phoneHours} hrs/day"
                            : "Not specified",
                      ),
                      _buildSummaryRow(
                        cs,
                        "Time spent towards Allah today",
                        _formatTimeSpent(data.startTime),
                      ),
                      if (data.intentionAnswer != null)
                        _buildSummaryRow(
                          cs,
                          "Your Intention",
                          data.intentionAnswer!,
                        ),
                      if (data.challengeAnswer != null)
                        _buildSummaryRow(
                          cs,
                          "Spiritual Goal",
                          data.challengeAnswer!,
                        ),
                      _buildSummaryRow(
                        cs,
                        "Commitment Level",
                        data.commitmentLevel ?? "Highly Committed",
                      ),
                      _buildSummaryRow(
                        cs,
                        "Quran Read",
                        "3 Personalized Ayahs",
                      ),
                      _buildSummaryRow(
                        cs,
                        "Spiritual Archetype",
                        _getSpiritualProfile(data),
                      ),
                      _buildSummaryRow(cs, "Status", "QUEST STARTED"),
                      _buildSummaryRow(cs, "Onboarding Reward", "200 Stars 🌟"),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: DuoButton(
                          onPressed: onBack,
                          backgroundColor: cs.secondaryContainer,
                          depthColor: cs.secondaryContainer.withValues(
                            alpha: 0.8,
                          ),
                          radius: 16,
                          child: Text(
                            "Back",
                            style: TextStyle(
                              fontSize: 16,
                              color: cs.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: DuoButton(
                          onPressed: onNext,
                          backgroundColor: cs.primary,
                          depthColor: cs.primary.withValues(alpha: 0.8),
                          radius: 16,
                          child: Text(
                            "Looks good",
                            style: TextStyle(
                              fontSize: 16,
                              color: cs.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
    );
  }

  Widget _buildSummaryRow(ColorScheme cs, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.6),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class AppFeedbackPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const AppFeedbackPage({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  State<AppFeedbackPage> createState() => _AppFeedbackPageState();
}

class _AppFeedbackPageState extends State<AppFeedbackPage> {
  bool _showReviewScreen = false;
  bool _continueEnabled = false;
  int _countdown = 3;
  Timer? _countdownTimer;
  final InAppReview _inAppReview = InAppReview.instance;

  String _formatTimeSpent(DateTime start) {
    final diff = DateTime.now().difference(start);
    final mins = (diff.inSeconds / 60.0).ceil();
    final clampedMins = mins.clamp(1, 9999);
    return "$clampedMins ${clampedMins == 1 ? 'minute' : 'minutes'}";
  }

  void _startCountdown() {
    _countdown = 3;
    _continueEnabled = false;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          _continueEnabled = true;
          t.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _showReviewAndNavigate() async {
    setState(() => _showReviewScreen = true);
    _startCountdown();
    HapticFeedback.mediumImpact();
    if (await _inAppReview.isAvailable()) {
      await _inAppReview.requestReview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: _showReviewScreen
            ? _buildReviewScreen(cs, tt)
            : _buildFeedbackScreen(cs, tt),
      ),
    );
  }

  Widget _buildFeedbackScreen(ColorScheme cs, TextTheme tt) {
    final timeStr = _formatTimeSpent(widget.data.startTime);
    return Column(
      key: const ValueKey('feedback_screen'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        Text(
          "That's the app!",
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "I hope this was the most fun $timeStr you've spent learning the Quran in days!",
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurface.withOpacity(0.55),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        Text(
          "So... what do you think?",
          style: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        DuoButton(
          onPressed: _showReviewAndNavigate,
          backgroundColor: cs.primary,
          depthColor: cs.primary.withOpacity(0.8),
          radius: 16,
          height: 60,
          child: Text(
            "Yes, I love it! 😍",
            style: TextStyle(
              fontSize: 18,
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        DuoButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            widget.onNext();
          },
          backgroundColor: cs.secondaryContainer,
          depthColor: cs.secondaryContainer.withOpacity(0.8),
          radius: 16,
          height: 60,
          child: Text(
            "I'd like to explore more",
            style: TextStyle(
              fontSize: 18,
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(flex: 1),
        Row(
          children: [
            Expanded(
              child: DuoButton(
                onPressed: widget.onBack,
                backgroundColor: cs.secondaryContainer,
                depthColor: cs.secondaryContainer.withOpacity(0.8),
                radius: 16,
                child: Text(
                  "Back",
                  style: TextStyle(
                    fontSize: 16,
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildReviewScreen(ColorScheme cs, TextTheme tt) {
    return Column(
      key: const ValueKey('review_screen'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Text(
          "Take a moment to rate us",
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        DuoButton(
          onPressed: () async {
            HapticFeedback.heavyImpact();
            await _inAppReview.openStoreListing();
          },
          backgroundColor: cs.primary,
          depthColor: cs.primary.withOpacity(0.8),
          radius: 16,
          height: 60,
          child: Text(
            "Rate on Google Play",
            style: TextStyle(
              fontSize: 18,
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(),
        DuoButton(
          onPressed: _continueEnabled
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onNext();
                }
              : null,
          backgroundColor: _continueEnabled
              ? cs.secondaryContainer
              : cs.secondaryContainer.withOpacity(0.4),
          depthColor: _continueEnabled
              ? cs.secondaryContainer.withOpacity(0.8)
              : cs.secondaryContainer.withOpacity(0.3),
          radius: 16,
          height: 56,
          child: Text(
            _continueEnabled ? "Continue" : "Continue in $_countdown...",
            style: TextStyle(
              fontSize: 16,
              color: _continueEnabled
                  ? cs.onSurface
                  : cs.onSurface.withOpacity(0.4),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }
}

class SetupPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  const SetupPage({
    required this.data,
    required this.onFinish,
    required this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          Text(
            data.displayName != null
                ? "Final setup, ${data.displayName}"
                : "Final setup",
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Enable these to get the most out of your journey",
            style: tt.bodyLarge,
          ),
          const SizedBox(height: 32),
          _permissionTile(
            cs,
            tt,
            Icons.notifications_active_rounded,
            "Prayer Reminders",
            "Get notified for suhoor, iftar, and prayer times",
            data.notificationsEnabled,
            () async {
              // NotificationService.requestPermissions() would be called here
            },
          ),
          const SizedBox(height: 12),
          _permissionTile(
            cs,
            tt,
            Icons.location_on_rounded,
            "Prayer Times",
            "Automatic prayer times based on your location",
            data.locationEnabled,
            () async {
              // Geolocator.requestPermission() would be called here
            },
          ),
          const Spacer(flex: 1),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: DuoButton(
                  onPressed: onBack,
                  backgroundColor: cs.secondaryContainer,
                  depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                  radius: 16,
                  child: Text(
                    "Back",
                    style: TextStyle(
                      fontSize: 16,
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: DuoButton(
                  onPressed: onFinish,
                  backgroundColor: cs.primary,
                  depthColor: cs.primary.withValues(alpha: 0.8),
                  radius: 16,
                  child: Text(
                    "Start Reflecting",
                    style: TextStyle(
                      fontSize: 16,
                      color: cs.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _permissionTile(
    ColorScheme cs,
    TextTheme tt,
    IconData icon,
    String title,
    String subtitle,
    bool enabled,
    VoidCallback onTap,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: cs.onSurface, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(subtitle, style: tt.bodySmall),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) {
              onTap();
            },
          ),
        ],
      ),
    );
  }
}
