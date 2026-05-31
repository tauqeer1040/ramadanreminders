import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../services/analogy_service.dart';
import '../../services/journal_service.dart';
import 'onboarding_data.dart';
import '../widgets/duo_button.dart';
import '../../theme/app_theme.dart';

class FirstJournalPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const FirstJournalPage({required this.data, required this.onNext, required this.onBack, super.key});

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
    _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    _onTextChanged(_controller.text);
    final removed = _suggestions.removeAt(index);
    _suggestionsKey.currentState?.removeItem(
      index,
      (context, animation) => _buildSuggestionItem(removed, animation, index),
      duration: const Duration(milliseconds: 300),
    );
  }

  Widget _buildSuggestionItem(String text, Animation<double> animation, int index) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return SizeTransition(
      sizeFactor: animation,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          label: Text(text, style: tt.labelSmall?.copyWith(color: cs.onSurface)),
          onPressed: () => _selectSuggestion(index, text),
          backgroundColor: cs.surfaceContainerHigh,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    final canContinue = _controller.text.trim().isNotEmpty || widget.data.journalEntry != null;

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
        hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.6), fontSize: 18),
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
                AnimatedOpacity(
                  opacity: keyboardInset == 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      Text("Your first reflection", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Write about your thoughts, hopes, or anything on your heart.", style: tt.bodyLarge),
                          const SizedBox(height: 8),
                          Text("This is your private space to reflect on your day.", style: tt.bodyLarge),
                          const SizedBox(height: 8),
                          Text("Share your struggles, your victories, and everything in between.", style: tt.bodyLarge),
                          const SizedBox(height: 8),
                          Text("Your words matter here.", style: tt.bodyLarge),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Image.asset('assets/photos/mascot/name.png', height: 200, fit: BoxFit.contain),
                      const SizedBox(height: 16),
                    ],
                    ),
                  ),
                  textField,
                const SizedBox(height: 12),
                Text('Prompt ideas', style: tt.labelMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: AnimatedList(
                    key: _suggestionsKey,
                    scrollDirection: Axis.horizontal,
                    controller: _suggestionsScrollController,
                    initialItemCount: _suggestions.length,
                    itemBuilder: (context, i, animation) => _buildSuggestionItem(_suggestions[i], animation, i),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: keyboardInset == 0 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: IgnorePointer(
            ignoring: keyboardInset != 0,
            child: Padding(
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
                            depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                            radius: 16,
                            child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
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
                            child: Text("Save & Continue", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
            ),
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

  const AiInsightPage({required this.data, required this.onNext, required this.onBack, super.key});

  @override
  State<AiInsightPage> createState() => _AiInsightPageState();
}

class _AiInsightPageState extends State<AiInsightPage> {
  bool _loading = true;
  double _progress = 0;
  final CardSwiperController _swiperController = CardSwiperController();
  List<_JournalCard> _cards = [];

  @override
  void initState() {
    super.initState();
    _simulateProgress();
    _generateCards();
  }

  void _simulateProgress() {
    final steps = [0.1, 0.18, 0.27, 0.35, 0.44, 0.52, 0.61, 0.73, 0.82, 0.91];
    for (var i = 0; i < steps.length; i++) {
      Future.delayed(Duration(milliseconds: 300 + i * 400), () {
        if (mounted && _loading) setState(() => _progress = steps[i]);
      });
    }
  }

  Future<void> _generateCards() async {
    final entry = widget.data.journalEntry;
    if (entry == null || entry.trim().isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final result = await AnalogyService.generateJournalAnalogies(entry);
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
      _loading = false;
    });
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
    return text.replaceAll(RegExp(r'— (Quran \d+:\d+|Tirmidhi|Bukhari|Muslim|Ahmad)'), '').trim();
  }

  List<Widget> _extractPills(String text) {
    final regex = RegExp(r'— (Quran \d+:\d+|Tirmidhi|Bukhari|Muslim|Ahmad)');
    final matches = regex.allMatches(text);
    if (matches.isEmpty) return [];
    final cs = Theme.of(context).colorScheme;
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
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
            ),
            child: Text(verse, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
          );
        }).toList(),
      ),
    ];
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
          const Spacer(flex: 1),
          if (_loading) ...[
            Text("Crafting your reflections...", style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
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
            Text("${(_progress * 100).round()}%", style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(flex: 1),
          ] else ...[
            const SizedBox(height: 24),
            Column(
              children: [
                Text("your life", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                Text(" + ", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                Text("the Holy Quran,", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                Text("Reflections for you${widget.data.displayName != null ? ", ${widget.data.displayName}" : ""}", style: tt.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text("Swipe through", style: tt.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)), textAlign: TextAlign.center),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              height: MediaQuery.of(context).size.height * 0.55,
              child: CardSwiper(
                controller: _swiperController,
                cardsCount: _cards.length,
                numberOfCardsDisplayed: _cards.length > 1 ? 2 : 1,
                isLoop: true,
                cardBuilder: (context, index, _, __) {
                  final card = _cards[index];
                  final pastelColors = [cs.primaryContainer, cs.secondaryContainer, cs.tertiaryContainer];
                  final bgColor = pastelColors[index % pastelColors.length];
                  return Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(card.icon, color: AppTheme.starGold, size: 24),
                            const SizedBox(width: 10),
                            _MarqueeText(card.title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
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
                                  style: tt.bodyLarge?.copyWith(height: 1.6),
                                  textAlign: TextAlign.center,
                                ),
                                ..._extractPills(card.content),
                              ],
                            ),
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
                    child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
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
                    child: Text("Continue", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
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
  const _JournalCard({required this.icon, required this.title, required this.content});
}

class CelebrationPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const CelebrationPage({required this.data, required this.onNext, required this.onBack, super.key});

  @override
  State<CelebrationPage> createState() => _CelebrationPageState();
}

class _CelebrationPageState extends State<CelebrationPage> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            colors: [cs.primary, cs.tertiary, AppTheme.starGold],
            numberOfParticles: 30,
            maxBlastForce: 20,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              Text("Congratulations!", style: tt.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
              const SizedBox(height: 12),
              Text(
                "You've completed your first reflection.",
                style: tt.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.primary, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("1", style: tt.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
                    Text("Day", style: tt.labelLarge?.copyWith(color: cs.onSurface)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text("Your streak starts today", style: tt.bodyLarge),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: DuoButton(
                      onPressed: widget.onBack,
                      backgroundColor: cs.secondaryContainer,
                      depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                      radius: 16,
                      child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
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
                      child: Text("Continue", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  // App store review prompt — integrated at emotional peak
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text("Enjoying the app? Leave a review!"), backgroundColor: cs.primary),
                  );
                },
                icon: Icon(Icons.star_rounded, size: 18, color: cs.onSurface),
                label: const Text("Leave a review"),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ],
    );
  }
}

class SummaryPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const SummaryPage({required this.data, required this.onNext, required this.onBack, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          Text("${data.displayName != null ? "${data.displayName}'s S" : "Your S"}piritual Profile", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _summaryTile(cs, tt, Icons.person_rounded, "Name", data.displayName ?? "Guest", cs.primaryContainer),
                if (data.journalEntry != null && data.journalEntry!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _summaryTile(cs, tt, Icons.auto_stories_rounded, "First Reflection", data.journalEntry!.length > 80 ? '${data.journalEntry!.substring(0, 80)}...' : data.journalEntry!, cs.tertiaryContainer),
                ],
                if (data.journalAnalogies.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _summaryTile(cs, tt, Icons.auto_awesome_rounded, "Insights", "${data.journalAnalogies.length} analogies generated", cs.secondaryContainer),
                ],
                const SizedBox(height: 8),
                _summaryTile(cs, tt, Icons.local_fire_department_rounded, "Streak", "Day 1 begins today!", cs.errorContainer.withValues(alpha: 0.3)),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: DuoButton(
                  onPressed: onBack,
                  backgroundColor: cs.secondaryContainer,
                  depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                  radius: 16,
                  child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
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
                  child: Text("Looks good", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _summaryTile(ColorScheme cs, TextTheme tt, IconData icon, String label, String value, Color bgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.onSurface, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tt.labelMedium),
                const SizedBox(height: 4),
                Text(value, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommitmentPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const CommitmentPage({required this.data, required this.onNext, required this.onBack, super.key});

  @override
  State<CommitmentPage> createState() => _CommitmentPageState();
}

class _CommitmentPageState extends State<CommitmentPage> {
  int? _selected;

  final _options = [
    ("Extremely committed", "I'm ready to grow closer to Allah"),
    ("Very committed", "I'll give it my best effort"),
    ("Somewhat committed", "I'm going to try"),
    ("Just exploring", "Let me see what this is about"),
  ];

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
          Icon(Icons.verified_rounded, size: 48, color: cs.onSurface),
          const SizedBox(height: 16),
          Text("How committed are you?", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Your honesty helps us support you better", style: tt.bodyLarge),
          const SizedBox(height: 32),
          ...List.generate(_options.length, (i) {
            final selected = _selected == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selected = i);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: selected ? cs.primaryContainer : cs.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: selected ? cs.onSurface : cs.onSurface.withValues(alpha: 0.7),
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_options[i].$1, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                              Text(_options[i].$2, style: tt.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.people_rounded, color: cs.onSurface, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Join 10,000+ Muslims reflecting daily",
                    style: tt.bodyMedium?.copyWith(color: cs.onSurface),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 1),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: DuoButton(
                  onPressed: widget.onBack,
                  backgroundColor: cs.secondaryContainer,
                  depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                  radius: 16,
                  child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: DuoButton(
                  onPressed: _selected != null
                      ? () {
                          widget.data.commitmentLevel = _options[_selected!].$1;
                          widget.onNext();
                        }
                      : null,
                  backgroundColor: cs.primary,
                  depthColor: cs.primary.withValues(alpha: 0.8),
                  radius: 16,
                  dimOnDisabled: true,
                  child: Text("Continue", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class SetupPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  const SetupPage({required this.data, required this.onFinish, required this.onBack, super.key});

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
          Text(data.displayName != null ? "Final setup, ${data.displayName}" : "Final setup", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Enable these to get the most out of your journey", style: tt.bodyLarge),
          const SizedBox(height: 32),
          _permissionTile(
            cs, tt,
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
            cs, tt,
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
                  child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
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
                  child: Text("Start Reflecting", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _permissionTile(ColorScheme cs, TextTheme tt, IconData icon, String title, String subtitle, bool enabled, VoidCallback onTap) {
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
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: cs.onSurface, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
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

class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  const _MarqueeText(this.text, {this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final ScrollController _scrollController = ScrollController();
  bool _overflowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  void _measure(_) {
    if (!mounted) return;
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    final availableWidth = context.size?.width ?? double.infinity;
    final overflows = textPainter.width > availableWidth;
    setState(() => _overflowing = overflows);
    if (overflows) _startScroll();
  }

  void _startScroll() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout();
    final availableWidth = context.size?.width ?? double.infinity;
    final scrollExtent = textPainter.width - availableWidth + 20;
    _animation = Tween(begin: 0.0, end: -scrollExtent).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    _controller.addListener(() {
      _scrollController.jumpTo(_animation.value);
    });
    Future.delayed(const Duration(seconds: 1), () => _controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _overflowing ? _scrollController : null,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style),
    );
  }
}
