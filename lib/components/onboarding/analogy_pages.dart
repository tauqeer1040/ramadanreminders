import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/analogy_service.dart';
import 'onboarding_data.dart';

class AnalogyQuestionPage extends StatefulWidget {
  final OnboardingData data;
  final String question;
  final List<String> pills;
  final String dataField;
  final VoidCallback onNext;

  const AnalogyQuestionPage({
    required this.data,
    required this.question,
    required this.pills,
    required this.dataField,
    required this.onNext,
    super.key,
  });

  @override
  State<AnalogyQuestionPage> createState() => _AnalogyQuestionPageState();
}

class _AnalogyQuestionPageState extends State<AnalogyQuestionPage> {
  int? _selectedIndex;
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
    } else if (_selectedIndex != null) {
      _setAnswer(widget.pills[_selectedIndex!]);
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

    final hasSelection = _selectedIndex != null || (_showCustom && _customController.text.trim().isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          Icon(Icons.auto_awesome_rounded, color: cs.primary, size: 28),
          const SizedBox(height: 12),
          Text(widget.question, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(widget.pills.length, (i) {
              final selected = _selectedIndex == i;
              return ChoiceChip(
                label: Text(widget.pills[i]),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    _selectedIndex = v ? i : null;
                    if (v) _showCustom = false;
                  });
                },
                selectedColor: cs.primaryContainer,
                backgroundColor: cs.surfaceContainer,
                labelStyle: TextStyle(
                  color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            if (_customController.text.trim().isNotEmpty)
              TextButton(
                onPressed: () {
                  _customController.clear();
                  setState(() {});
                },
                child: const Text("Clear"),
              ),
          ],
          const Spacer(flex: 1),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: hasSelection ? _onContinue : null,
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text("Continue", style: TextStyle(fontSize: 16)),
            ),
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
  final bool isLast;

  const AnalogyRevealPage({
    required this.data,
    required this.question,
    required this.analogyField,
    required this.onNext,
    this.isLast = false,
    super.key,
  });

  @override
  State<AnalogyRevealPage> createState() => _AnalogyRevealPageState();
}

class _AnalogyRevealPageState extends State<AnalogyRevealPage> {
  bool _loading = true;
  String _analogy = '';
  bool _revealed = false;
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
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _revealed = true);
    });
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          if (_loading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text("Crafting your personal analogy...", style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          ] else ...[
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 40, color: cs.primary),
                    const SizedBox(height: 16),
                    AnimatedOpacity(
                      opacity: _revealed ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 800),
                      child: AnimatedSlide(
                        offset: _revealed ? Offset.zero : const Offset(0, 0.2),
                        duration: const Duration(milliseconds: 800),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cs.primaryContainer.withValues(alpha: 0.6), cs.secondaryContainer.withValues(alpha: 0.3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.auto_awesome_rounded, color: cs.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Text("Your analogy", style: tt.labelLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _analogy,
                                style: tt.bodyLarge?.copyWith(
                                  height: 1.6,
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const Spacer(flex: 1),
          if (!_loading)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: widget.onNext,
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text(widget.isLast ? "See all my analogies" : "Continue", style: const TextStyle(fontSize: 16)),
              ),
            ),
          if (_loading) const SizedBox(height: 56),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
