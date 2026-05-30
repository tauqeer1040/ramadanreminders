import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audiotags/audiotags.dart';
import 'onboarding_data.dart';
import '../../services/audio_service.dart';
import '../widgets/duo_button.dart';

class WelcomePage extends StatelessWidget {
  final VoidCallback onNext;

  const WelcomePage({required this.onNext, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Image.asset(
            'assets/photos/mascot/hi.webp',
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),
          Text(
            "Assalamualikum...",
            style: tt.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: cs.onSurface,
              fontSize: 32,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 2),
          DuoButton(
            onPressed: onNext,
            backgroundColor: cs.primary,
            depthColor: cs.primary.withValues(alpha: 0.8),
            radius: 16,
            child: const Text("Waalikumassalam 😄👋", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class MusicSelectionPage extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const MusicSelectionPage({required this.onNext, required this.onBack, super.key});

  @override
  State<MusicSelectionPage> createState() => _MusicSelectionPageState();
}

class _MusicSelectionPageState extends State<MusicSelectionPage> {
  int _selectedTrack = 0;
  List<Uint8List?> _covers = [null, null];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCovers();
  }

  Future<void> _loadCovers() async {
    try {
      final paths = [
        'assets/tunes/1_A.M_Study_Session_lofi_hip_hop_5min.m4a',
        'assets/tunes/After_Dark_in_Cairo_Arabic_Melodies_Jazz_Fusion_for_Late_Night_Focus_Study_5min.m4a'
      ];
      for (int i = 0; i < paths.length; i++) {
        final byteData = await rootBundle.load(paths[i]);
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/${paths[i].split('/').last}');
        await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
        final tag = await AudioTags.read(file.path);
        if (tag?.pictures.isNotEmpty == true) {
          _covers[i] = tag!.pictures.first.bytes;
        }
      }
    } catch (e) {
      debugPrint("Error loading covers: $e");
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text("Ready for the\nOnboarding?", style: tt.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 24),
          Text(
            "Pick some music, get\ncomfortable.",
            style: tt.headlineSmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),
          Text(
            "By the end, you'd have written your first journal, an AI generated reflection of your journal entry, completed 3 tasks, and earned 200 stars!",
            style: tt.bodyLarge?.copyWith(color: cs.onSurface, fontStyle: FontStyle.italic),
          ),
          const Spacer(flex: 1),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTrack = 0);
                      BackgroundMusicService().play('tunes/1_A.M_Study_Session_lofi_hip_hop_5min.m4a');
                    },
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _selectedTrack == 0 ? cs.primary : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: _covers[0] != null
                                ? Image.memory(_covers[0]!, height: 160, width: double.infinity, fit: BoxFit.cover)
                                : Container(height: 160, color: cs.surfaceContainerHighest, child: const Icon(Icons.music_note, size: 48)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text("1am study session", style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTrack = 1);
                      BackgroundMusicService().play('tunes/After_Dark_in_Cairo_Arabic_Melodies_Jazz_Fusion_for_Late_Night_Focus_Study_5min.m4a');
                    },
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _selectedTrack == 1 ? cs.primary : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: _covers[1] != null
                                ? Image.memory(_covers[1]!, height: 160, width: double.infinity, fit: BoxFit.cover)
                                : Container(height: 160, color: cs.surfaceContainerHighest, child: const Icon(Icons.music_note, size: 48)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text("after dark in cairo", style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text("Continue", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                    ],
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
}

class NamePage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const NamePage({required this.data, required this.onNext, required this.onBack, super.key});

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.data.displayName != null) {
      _controller.text = widget.data.displayName!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, bottomInset + 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(24)),
            child: Icon(Icons.person_rounded, size: 40, color: cs.onSurface),
          ),
          const SizedBox(height: 24),
          Text("What should we call you?", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 8),
          Text("So we can personalize your experience", style: tt.bodyLarge?.copyWith(color: cs.onSurface)),
          const SizedBox(height: 32),
          TextField(
            controller: _controller,
            maxLength: 24,
            maxLengthEnforcement: MaxLengthEnforcement.truncateAfterCompositionEnds,
            textCapitalization: TextCapitalization.words,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: "Your name",
              hintStyle: tt.headlineSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w400),
              filled: true,
              fillColor: cs.surfaceContainer,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              counter: const SizedBox.shrink(),
            ),
          ),
          const Spacer(flex: 2),
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
                  onPressed: () {
                    widget.data.displayName = _controller.text.trim().isNotEmpty ? _controller.text.trim() : null;
                    widget.onNext();
                  },
                  backgroundColor: cs.primary,
                  depthColor: cs.primary.withValues(alpha: 0.8),
                  radius: 16,
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Continue", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20, color: cs.onSurface),
                    ],
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
}

class AgePhonePage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const AgePhonePage({required this.data, required this.onNext, required this.onBack, super.key});

  @override
  State<AgePhonePage> createState() => _AgePhonePageState();
}

class _AgePhonePageState extends State<AgePhonePage> {
  int _age = 25;
  double _phoneHours = 4;

  @override
  void initState() {
    super.initState();
    if (widget.data.age != null) _age = widget.data.age!;
    if (widget.data.phoneHours != null) _phoneHours = widget.data.phoneHours!.toDouble();
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
          // Text("A little about you${widget.data.displayName != null ? ", ${widget.data.displayName}" : ""}", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
          // const SizedBox(height: 8),
          // Text("This helps us personalize your journey", style: tt.bodyLarge?.copyWith(color: cs.onSurface)),
          // const SizedBox(height: 40),
          // TODO: age question — uncomment when ready
          // Text("How old are you?", style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
          // const SizedBox(height: 12),
          // SizedBox(
          //   height: 120,
          //   child: ListWheelScrollView.useDelegate(
          //     itemExtent: 40,
          //     diameterRatio: 1.5,
          //     onSelectedItemChanged: (i) => setState(() => _age = i + 10),
          //     childDelegate: ListWheelChildBuilderDelegate(
          //       builder: (ctx, i) {
          //         final val = i + 10;
          //         final isSelected = val == _age;
          //         return Center(
          //           child: Text(
          //             "$val",
          //             style: tt.headlineMedium?.copyWith(
          //               fontWeight: isSelected ? FontWeight.bold : FontWeight.w300,
          //               color: isSelected ? cs.onSurface : cs.onSurface.withValues(alpha: 0.5),
          //             ),
          //           ),
          //         );
          //       },
          //       childCount: 70,
          //     ),
          //   ),
          // ),
          // const SizedBox(height: 32),
          Text("How many hours do you spend on your phone daily${widget.data.displayName != null ? " ${widget.data.displayName}" : ""}?", style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 8),
          Text("${_phoneHours.toInt()} hrs/day", style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
          Slider(
            value: _phoneHours,
            min: 0,
            max: 16,
            divisions: 16,
            onChanged: (v) => setState(() => _phoneHours = v),
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
                  height: 56,
                  child: Text("Back", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: DuoButton(
                  onPressed: () {
                    widget.data.age = _age;
                    widget.data.phoneHours = _phoneHours.toInt();
                    widget.onNext();
                  },
                  backgroundColor: cs.primary,
                  depthColor: cs.primary.withValues(alpha: 0.8),
                  radius: 16,
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Continue", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20, color: cs.onSurface),
                    ],
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
}

class BombshellPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BombshellPage({required this.data, required this.onNext, required this.onBack, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final phoneHours = data.phoneHours ?? 4;
    final totalPhoneHours = phoneHours * 30;
    final reflectionHours = (totalPhoneHours * 0.1).round();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 1),
          Text("Did you know?", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                  Text(
                    "~${totalPhoneHours}hours",
                    style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Text(
                  "That's roughly how much time you'll spend on your phone every month!",
                  style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.tertiaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.tertiary.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: cs.onSurface, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      "Imagine if...",
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Just 10% of that time became spiritual reflection. That's $reflectionHours hours of growth.",
                  style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                  textAlign: TextAlign.center,
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
                  onPressed: onBack,
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
                  onPressed: onNext,
                  backgroundColor: cs.primary,
                  depthColor: cs.primary.withValues(alpha: 0.8),
                  radius: 16,
                  height: 56,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Let's do this", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20, color: cs.onSurface),
                    ],
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
}

class BridgePage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BridgePage({required this.onNext, required this.onBack, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Icon(Icons.wb_twilight_rounded, size: 80, color: cs.primary),
          const SizedBox(height: 24),
          Text("It doesn't have to be this way", style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 12),
          Text(
            "A few minutes of reflection each day can transform your Dunya and your Akhirah. "
            "\n"
            "Let's build a personal plan that works for you.",
            style: tt.bodyLarge?.copyWith(color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "One reflection at a time.",
            style: tt.bodyLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.w600),
          ),
          const Spacer(flex: 2),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Start my plan", style: TextStyle(fontSize: 16, color: cs.onSurface, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20, color: cs.onSurface),
                    ],
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
}
