import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import '../../services/analogy_service.dart';
import 'onboarding_data.dart';
import '../widgets/duo_button.dart';
import '../../theme/app_theme.dart';

class AnalogyQuestionPage extends StatefulWidget {
  final OnboardingData data;
  final String question;
  final List<String> pills;
  final String dataField;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool useDuoButtons;
  final bool showName;

  const AnalogyQuestionPage({
    required this.data,
    required this.question,
    required this.pills,
    required this.dataField,
    required this.onNext,
    required this.onBack,
    this.useDuoButtons = false,
    this.showName = false,
    super.key,
  });

  @override
  State<AnalogyQuestionPage> createState() => _AnalogyQuestionPageState();
}

class _AnalogyQuestionPageState extends State<AnalogyQuestionPage> {
  final Set<int> _selectedIndices = {};
  bool _showCustom = false;
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _onContinue() {
    HapticFeedback.lightImpact();
    if (_showCustom && _customController.text.trim().isNotEmpty) {
      _setAnswer(_customController.text.trim());
    } else if (_selectedIndices.isNotEmpty) {
      _setAnswer(_selectedIndices.map((i) => widget.pills[i]).join("; "));
    }
    widget.onNext();
  }

  void _setAnswer(String answer) {
    switch (widget.dataField) {
      case 'intention':
        widget.data.intentionAnswer = answer;
        break;
      case 'heart':
        widget.data.heartAnswer = answer;
        break;
      case 'challenge':
        widget.data.challengeAnswer = answer;
        break;
      case 'journey':
        widget.data.journeyAnswer = answer;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final hasSelection = _selectedIndices.isNotEmpty || (_showCustom && _customController.text.trim().isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          const SizedBox(height: 32),
          Text(widget.showName && widget.data.displayName != null ? '${widget.question.substring(0, widget.question.length - 1)}, ${widget.data.displayName}?' : widget.question, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          if (widget.useDuoButtons) ...[
            const SizedBox(height: 8),
            Text("Pick all that are relevant to you", style: tt.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
          ],
          const SizedBox(height: 24),
          if (widget.useDuoButtons)
            Column(
              children: List.generate(widget.pills.length, (i) {
                final selected = _selectedIndices.contains(i);
                final colors = [
                  const Color(0xFFE85D75), // vivid pink
                  const Color(0xFF8E4BFF), // vivid purple
                  const Color(0xFF4AA3E9), // vivid blue
                  const Color(0xFFF0C040), // vivid gold
                ];
                final c = colors[i % colors.length];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DuoButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedIndices.contains(i)) {
                            _selectedIndices.remove(i);
                          } else {
                            _selectedIndices.add(i);
                          }
                        });
                      },
                      backgroundColor: selected ? c : cs.secondaryContainer,
                      depthColor: selected ? Color.alphaBlend(Colors.black.withValues(alpha: 0.35), c) : cs.secondaryContainer.withValues(alpha: 0.8),
                      radius: 16,
                      child: Text(
                        widget.pills[i],
                        style: TextStyle(
                          fontSize: 16,
                          color: selected ? Colors.black : AppTheme.starWhite,
                          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            )
          else ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(widget.pills.length, (i) {
                final selected = _selectedIndices.contains(i);
                return ChoiceChip(
                  label: Text(widget.pills[i]),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) { _selectedIndices.add(i); _showCustom = false; }
                      else { _selectedIndices.remove(i); }
                    });
                  },
                  selectedColor: cs.primaryContainer,
                  backgroundColor: cs.surfaceContainer,
                  labelStyle: TextStyle(
                    color: selected ? cs.onSurface : cs.onSurface.withValues(alpha: 0.7),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  side: BorderSide(color: selected ? cs.onSurface : cs.outlineVariant),
                );
              }),
            ),
            const SizedBox(height: 16),
            if (!_showCustom)
              TextButton.icon(
                onPressed: () => setState(() => _showCustom = true),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text("Write your own"),
              )
            else ...[
              TextField(
                controller: _customController,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Share your thoughts...",
                  filled: true,
                  fillColor: cs.surfaceContainer,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DuoButton(
                      onPressed: () {
                        setState(() {
                          _showCustom = false;
                          _customController.clear();
                        });
                      },
                      backgroundColor: cs.surfaceContainer,
                      depthColor: cs.surfaceContainer.withValues(alpha: 0.8),
                      radius: 16,
                      child: Text("Cancel", style: TextStyle(fontSize: 16, color: cs.onSurface)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DuoButton(
                      onPressed: _customController.text.trim().isNotEmpty ? () => _onContinue() : null,
                      backgroundColor: cs.primary,
                      depthColor: cs.primary.withValues(alpha: 0.8),
                      radius: 16,
                      dimOnDisabled: true,
                      child: Text("Submit", style: TextStyle(fontSize: 16, color: cs.onSurface)),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (!_showCustom)
              TextButton.icon(
                onPressed: () => setState(() => _showCustom = true),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text("Write your own"),
              )
            else ...[
              TextField(
                controller: _customController,
                maxLines: 3,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Share your thoughts...",
                  filled: true,
                  fillColor: cs.surfaceContainer,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DuoButton(
                      onPressed: () {
                        setState(() {
                          _showCustom = false;
                          _customController.clear();
                        });
                      },
                      backgroundColor: cs.surfaceContainer,
                      depthColor: cs.surfaceContainer.withValues(alpha: 0.8),
                      radius: 16,
                      child: Text("Cancel", style: TextStyle(fontSize: 16, color: cs.onSurface)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DuoButton(
                      onPressed: _customController.text.trim().isNotEmpty ? () => _onContinue() : null,
                      backgroundColor: cs.primary,
                      depthColor: cs.primary.withValues(alpha: 0.8),
                      radius: 16,
                      dimOnDisabled: true,
                      child: Text("Submit", style: TextStyle(fontSize: 16, color: cs.onSurface)),
                    ),
                  ),
                ],
              ),
            ],
          ],
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
                  height: 56,
                  child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: DuoButton(
                  onPressed: hasSelection ? _onContinue : null,
                  backgroundColor: cs.primary,
                  depthColor: cs.primary.withValues(alpha: 0.8),
                  radius: 16,
                  height: 56,
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

class AnalogyRevealPage extends StatefulWidget {
  final OnboardingData data;
  final String question;
  final String analogyField;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool isLast;

  const AnalogyRevealPage({
    required this.data,
    required this.question,
    required this.analogyField,
    required this.onNext,
    required this.onBack,
    this.isLast = false,
    super.key,
  });

  @override
  State<AnalogyRevealPage> createState() => _AnalogyRevealPageState();
}

class _AnalogyRevealPageState extends State<AnalogyRevealPage> {
  bool _loading = true;
  String _analogy = '';
  late final String _answer;

  @override
  void initState() {
    super.initState();
    _answer = _getAnswer();
    _generate();
  }

  String _getAnswer() {
    switch (widget.analogyField) {
      case 'intention': return widget.data.intentionAnswer ?? '';
      case 'heart': return widget.data.heartAnswer ?? '';
      case 'challenge': return widget.data.challengeAnswer ?? '';
      case 'journey': return widget.data.journeyAnswer ?? '';
      default: return '';
    }
  }

  Future<void> _generate() async {
    final result = await AnalogyService.generateAnalogy(
      question: widget.question,
      answer: _answer,
    );
    if (!mounted) return;
    setState(() {
      _analogy = result;
      _loading = false;
    });
    _saveAnalogy(result);
    Confetti.launch(
      context,
      options: ConfettiOptions(
        particleCount: 40,
        spread: 60,
        y: 0.5,
        scalar: 1.2,
        colors: const [AppTheme.neonPurple, AppTheme.starGold, Color(0xFFF4A6B8), Color(0xFF81D4FA)],
      ),
    );
  }

  void _saveAnalogy(String analogy) {
    switch (widget.analogyField) {
      case 'intention':
        widget.data.intentionAnalogy = analogy;
        break;
      case 'heart':
        widget.data.heartAnalogy = analogy;
        break;
      case 'challenge':
        widget.data.challengeAnalogy = analogy;
        break;
      case 'journey':
        widget.data.journeyAnalogy = analogy;
        break;
    }
  }

  List<Widget> _extractVerses(String text) {
    final regex = RegExp(r'— Quran \d+:\d+');
    final matches = regex.allMatches(text);
    if (matches.isEmpty) return [];
    final cs = Theme.of(context).colorScheme;
    return [
      const SizedBox(height: 20),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: matches.map((m) {
          final verse = m.group(0)!.replaceFirst('— ', '');
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_loading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    Text("Crafting your personal analogy${widget.data.displayName != null ? ", ${widget.data.displayName}" : ""}...", style: tt.bodyLarge),
                  ] else ...[
                    const SizedBox(height: 32),
                    Text("Your first analogy", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Image.asset('assets/photos/mascot/name.png', height: 200, fit: BoxFit.contain),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [cs.primaryContainer.withValues(alpha: 0.6), cs.secondaryContainer.withValues(alpha: 0.3)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _analogy,
                            style: tt.titleLarge?.copyWith(
                              height: 1.6,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                            softWrap: true,
                          ),
                          ..._extractVerses(_analogy),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 48),
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
                            child: Text(widget.isLast ? "See all my analogies" : "Continue", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  if (_loading) const SizedBox(height: 56),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SwiperAnalogyPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const SwiperAnalogyPage({required this.data, required this.onNext, required this.onBack, super.key});

  @override
  State<SwiperAnalogyPage> createState() => _SwiperAnalogyPageState();
}

class _SwiperAnalogyPageState extends State<SwiperAnalogyPage> {
  final CardSwiperController _swiperController = CardSwiperController();
  List<String> _analogies = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalogies();
  }

  Future<void> _loadAnalogies() async {
    final entry = widget.data.journalEntry;
    if (entry == null || entry.trim().isEmpty) {
      setState(() {
        _analogies = AnalogyService.fallbackJournalAnalogies;
        _loading = false;
      });
      return;
    }
    final result = await AnalogyService.generateJournalAnalogies(entry);
    if (!mounted) return;
    setState(() {
      _analogies = result;
      _loading = false;
    });
    widget.data.journalAnalogies = result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 1),
              Text("Your Analogies", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Swipe through your personalized reflections", style: tt.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
              const SizedBox(height: 32),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: CardSwiper(
                    controller: _swiperController,
                    cardsCount: _analogies.length,
                    numberOfCardsDisplayed: _analogies.length > 1 ? 2 : 1,
                    isLoop: true,
                    cardBuilder: (context, index, _, __) {
                      return Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cs.primaryContainer.withValues(alpha: 0.6), cs.secondaryContainer.withValues(alpha: 0.3)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded, color: AppTheme.starGold, size: 28),
                                const SizedBox(height: 20),
                                Text(
                                  _analogies[index],
                                  style: tt.titleMedium?.copyWith(height: 1.6, fontStyle: FontStyle.italic),
                                  textAlign: TextAlign.center,
                                ),
                                if (index < _analogies.length) ...[
                                  const SizedBox(height: 20),
                                  ..._extractVersesStatic(_analogies[index], cs),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }

  static List<Widget> _extractVersesStatic(String text, ColorScheme cs) {
    final regex = RegExp(r'— Quran \d+:\d+');
    final matches = regex.allMatches(text);
    if (matches.isEmpty) return [];
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: matches.map((m) {
          final verse = m.group(0)!.replaceFirst('— ', '');
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
}
