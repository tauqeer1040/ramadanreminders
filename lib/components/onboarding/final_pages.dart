import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import '../../services/journal_service.dart';
import 'onboarding_data.dart';

class FirstJournalPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;

  const FirstJournalPage({required this.data, required this.onNext, super.key});

  @override
  State<FirstJournalPage> createState() => _FirstJournalPageState();
}

class _FirstJournalPageState extends State<FirstJournalPage> {
  final _controller = TextEditingController();
  final _journalService = JournalService();
  final List<String> _selectedTags = [];
  bool _saving = false;

  final _tagOptions = ["Gratitude", "Reflection", "Prayer", "Hope", "Struggle"];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final canContinue = _controller.text.trim().isNotEmpty || widget.data.journalEntry != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          Text("Your first reflection", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Write about your thoughts, hopes, or anything on your heart.", style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today I am feeling...", style: tt.labelLarge?.copyWith(color: cs.primary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Share your reflection...",
                    filled: true,
                    fillColor: cs.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text("Tags", style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tagOptions.map((tag) {
              final selected = _selectedTags.contains(tag);
              return ChoiceChip(
                label: Text(tag),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) { _selectedTags.add(tag); } else { _selectedTags.remove(tag); }
                  });
                },
                selectedColor: cs.primaryContainer,
                backgroundColor: cs.surface,
                labelStyle: TextStyle(
                  color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide(color: selected ? cs.primary : cs.outlineVariant),
              );
            }).toList(),
          ),
          const Spacer(flex: 1),
          if (_saving)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: canContinue ? _handleSave : null,
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("Save & Continue", style: TextStyle(fontSize: 16)),
              ),
            ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final text = _controller.text.trim();
    widget.data.journalEntry = text;
    widget.data.journalTags = List.from(_selectedTags);
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

  const AiInsightPage({required this.data, required this.onNext, super.key});

  @override
  State<AiInsightPage> createState() => _AiInsightPageState();
}

class _AiInsightPageState extends State<AiInsightPage> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _revealed = true);
    });
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
          if (!_revealed) ...[
            Icon(Icons.auto_awesome_rounded, size: 48, color: cs.primary),
            const SizedBox(height: 24),
            Text("Reflecting on your words...", style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ] else ...[
            Icon(Icons.lightbulb_rounded, size: 48, color: cs.tertiary),
            const SizedBox(height: 16),
            Text("A thought for you", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: cs.tertiary.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    "Your willingness to reflect is itself an act of worship. "
                    "Every moment you pause and turn your heart toward gratitude, "
                    "you water the seeds of faith within you.",
                    style: tt.bodyLarge?.copyWith(height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '"And He gave you all that you asked of Him." — Quran 14:34',
                      style: tt.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(flex: 1),
          if (_revealed)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: widget.onNext,
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text("Continue", style: TextStyle(fontSize: 16)),
              ),
            ),
          if (!_revealed) const SizedBox(height: 56),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class CelebrationPage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;

  const CelebrationPage({required this.data, required this.onNext, super.key});

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
            colors: [cs.primary, cs.tertiary, const Color(0xFFD4AF37)],
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
              Text("Congratulations!", style: tt.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
              const SizedBox(height: 12),
              Text(
                "You've completed your first reflection.",
                style: tt.titleLarge?.copyWith(color: cs.onSurfaceVariant),
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
                    Text("1", style: tt.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
                    Text("Day", style: tt.labelLarge?.copyWith(color: cs.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text("Your streak starts today", style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: widget.onNext,
                  style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("Continue", style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  // App store review prompt — integrated at emotional peak
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text("Enjoying the app? Leave a review!"), backgroundColor: cs.primary),
                  );
                },
                icon: Icon(Icons.star_rounded, size: 18, color: cs.primary),
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

  const SummaryPage({required this.data, required this.onNext, super.key});

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
          Text("Your Ramadan Profile", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: [
                _summaryTile(cs, tt, Icons.person_rounded, "Name", data.displayName ?? "Guest", cs.primaryContainer),
                if (data.intentionAnalogy != null) ...[
                  const SizedBox(height: 8),
                  _summaryTile(cs, tt, Icons.auto_awesome_rounded, "Your Intention", data.intentionAnswer ?? "", cs.secondaryContainer),
                ],
                if (data.journalEntry != null && data.journalEntry!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _summaryTile(cs, tt, Icons.auto_stories_rounded, "First Reflection", data.journalEntry!.length > 80 ? '${data.journalEntry!.substring(0, 80)}...' : data.journalEntry!, cs.tertiaryContainer),
                ],
                const SizedBox(height: 8),
                _summaryTile(cs, tt, Icons.local_fire_department_rounded, "Streak", "Day 1 begins today!", cs.errorContainer.withValues(alpha: 0.3)),
                if (data.challengeAnalogy != null) ...[
                  const SizedBox(height: 8),
                  _summaryTile(cs, tt, Icons.analytics_rounded, "Your Goal", data.challengeAnswer ?? "Grow spiritually", cs.primaryContainer),
                ],
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text("Looks good", style: TextStyle(fontSize: 16)),
            ),
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
                Text(label, style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
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

  const CommitmentPage({required this.data, required this.onNext, super.key});

  @override
  State<CommitmentPage> createState() => _CommitmentPageState();
}

class _CommitmentPageState extends State<CommitmentPage> {
  int? _selected;

  final _options = [
    ("Extremely committed", "I'm ready to transform my Ramadan"),
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
          Icon(Icons.verified_rounded, size: 48, color: cs.primary),
          const SizedBox(height: 16),
          Text("How committed are you?", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Your honesty helps us support you better", style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
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
                          color: selected ? cs.primary : cs.onSurfaceVariant,
                          size: 24,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_options[i].$1, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                              Text(_options[i].$2, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
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
                Icon(Icons.people_rounded, color: cs.secondary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Join 10,000+ Muslims reflecting this Ramadan",
                    style: tt.bodyMedium?.copyWith(color: cs.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 1),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _selected != null
                  ? () {
                      widget.data.commitmentLevel = _options[_selected!].$1;
                      widget.onNext();
                    }
                  : null,
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

class SetupPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onFinish;

  const SetupPage({required this.data, required this.onFinish, super.key});

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
          Text("Final setup", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Enable these to get the most out of Ramadan Reflections", style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
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
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: onFinish,
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              child: const Text("Start Reflecting", style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onFinish,
            child: const Text("Skip setup, I'll do it later"),
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
            child: Icon(icon, color: cs.onPrimaryContainer, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          Switch(
            value: enabled,
            onChanged: (v) {
              onTap();
              // Toggle handled by parent reconstruction
            },
          ),
        ],
      ),
    );
  }
}
