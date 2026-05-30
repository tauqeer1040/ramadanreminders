import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
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

  const AnalogyQuestionPage({
    required this.data,
    required this.question,
    required this.pills,
    required this.dataField,
    required this.onNext,
    required this.onBack,
    this.useDuoButtons = false,
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
          Icon(Icons.auto_awesome_rounded, color: cs.onSurface, size: 28),
          const SizedBox(height: 12),
          Text(widget.question, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          if (widget.useDuoButtons) ...[
            const SizedBox(height: 8),
            Text("Pick all that are relevant to you", style: tt.bodyLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.7))),
          ],
          const SizedBox(height: 24),
          if (widget.useDuoButtons)
            Column(
              children: List.generate(widget.pills.length, (i) {
                final selected = _selectedIndices.contains(i);
                final anySelected = _selectedIndices.isNotEmpty;
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
                      boxShadow: [
                        BoxShadow(
                          color: c.withValues(alpha: 0.5),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
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
                      backgroundColor: selected || !anySelected ? c : c.withValues(alpha: 0.4),
                      depthColor: selected || !anySelected ? Color.alphaBlend(Colors.black.withValues(alpha: 0.35), c) : Color.alphaBlend(Colors.black.withValues(alpha: 0.6), c.withValues(alpha: 0.4)),
                      radius: 16,
                      child: Text(
                        widget.pills[i],
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black,
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
                    Text("Crafting your personal analogy...", style: tt.bodyLarge),
                  ] else ...[
                    Icon(Icons.auto_awesome_rounded, size: 48, color: cs.onSurface),
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
                          Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, color: cs.onSurface, size: 24),
                              const SizedBox(width: 8),
                              Text("Your analogy", style: tt.titleMedium?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            _analogy,
                            style: tt.titleLarge?.copyWith(
                              height: 1.6,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                            softWrap: true,
                          ),
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
