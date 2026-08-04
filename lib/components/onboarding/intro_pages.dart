import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audiotags/audiotags.dart';
import 'onboarding_data.dart';
import '../../services/audio_service.dart';
import '../../services/analytics_service.dart';
import '../widgets/duo_button.dart';

class WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback? onSkipToLogin;

  const WelcomePage({required this.onNext, this.onSkipToLogin, super.key});

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
            sfxType: DuoSfxType.positive,
            child: const Text(
              "Waalikumassalam 😄👋",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (onSkipToLogin != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: onSkipToLogin,
                child: Text(
                  "I already have an account",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.45),
                    decoration: TextDecoration.underline,
                    decorationColor: cs.onSurface.withValues(alpha: 0.25),
                  ),
                ),
              ),
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

  const MusicSelectionPage({
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  State<MusicSelectionPage> createState() => _MusicSelectionPageState();
}

class _MusicSelectionPageState extends State<MusicSelectionPage> {
  int _selectedTrack = 0;
  final List<Uint8List?> _covers = [null, null];
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
        'assets/tunes/After_Dark_in_Cairo_Arabic_Melodies_Jazz_Fusion_for_Late_Night_Focus_Study_5min.m4a',
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
          Text(
            "Ready for the\nOnboarding?",
            style: tt.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Pick some music, get\ncomfortable.",
            style: tt.headlineSmall?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "By the end, you'd have written your first journal, unlocked 3 scratch cards (containing personalized AI insights from the Holy Quran), named your Cat, and earned 200 stars!",
            style: tt.bodyLarge?.copyWith(
              color: cs.onSurface,
              fontStyle: FontStyle.italic,
            ),
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
                      AnalyticsService.instance.logEvent('onboarding_music_selected', params: {'index': '0'});
                      BackgroundMusicService().play(
                        'tunes/1_A.M_Study_Session_lofi_hip_hop_5min.m4a',
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _selectedTrack == 0
                                  ? cs.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: _covers[0] != null
                                ? Image.memory(
                                    _covers[0]!,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    height: 160,
                                    color: cs.surfaceContainerHighest,
                                    child: const Icon(
                                      Icons.music_note,
                                      size: 48,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "1am study session",
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTrack = 1);
                      AnalyticsService.instance.logEvent('onboarding_music_selected', params: {'index': '1'});
                      BackgroundMusicService().play(
                        'tunes/After_Dark_in_Cairo_Arabic_Melodies_Jazz_Fusion_for_Late_Night_Focus_Study_5min.m4a',
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _selectedTrack == 1
                                  ? cs.primary
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: _covers[1] != null
                                ? Image.memory(
                                    _covers[1]!,
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    height: 160,
                                    color: cs.surfaceContainerHighest,
                                    child: const Icon(
                                      Icons.music_note,
                                      size: 48,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "after dark in cairo",
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                  sfxType: DuoSfxType.negative,
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
                  sfxType: DuoSfxType.positive,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        "Continue",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
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

  const NamePage({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  State<NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<NamePage> {
  final _userController = TextEditingController();
  final _catController = TextEditingController();
  final _userFocusNode = FocusNode();
  final _catFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.data.displayName != null) {
      _userController.text = widget.data.displayName!;
    }
    if (widget.data.catName != null) {
      _catController.text = widget.data.catName!;
    }
  }

  @override
  void dispose() {
    _userController.dispose();
    _catController.dispose();
    _userFocusNode.dispose();
    _catFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardVisible = bottomInset > 0;

    return Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, bottomInset + 48),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: isKeyboardVisible ? 16 : 40),
                Image.asset(
                  "assets/photos/mascot/name.png",
                  height: isKeyboardVisible ? 100 : 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                Text(
                  "What should we call each other?",
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Give yourself and me a name",
                  style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _userController,
                  focusNode: _userFocusNode,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _catFocusNode.requestFocus(),
                  maxLength: 24,
                  maxLengthEnforcement:
                      MaxLengthEnforcement.truncateAfterCompositionEnds,
                  textCapitalization: TextCapitalization.words,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "😎 You can call me...",
                    hintStyle: tt.titleMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    counter: const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "❤️",
                  style: const TextStyle(color: Colors.red, fontSize: 24),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _catController,
                  focusNode: _catFocusNode,
                  autofocus: false,
                  textInputAction: TextInputAction.done,
                  maxLength: 24,
                  maxLengthEnforcement:
                      MaxLengthEnforcement.truncateAfterCompositionEnds,
                  textCapitalization: TextCapitalization.words,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: "😽 I'll name you...",
                    hintStyle: tt.titleMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    counter: const SizedBox.shrink(),
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
                        depthColor: cs.secondaryContainer.withValues(
                          alpha: 0.8,
                        ),
                        radius: 16,
                        height: 56,
                        sfxType: DuoSfxType.negative,
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
                        onPressed: () {
                          widget.data.displayName =
                              _userController.text.trim().isNotEmpty
                              ? _userController.text.trim()
                              : null;
                          widget.data.catName =
                              _catController.text.trim().isNotEmpty
                              ? _catController.text.trim()
                              : null;
                          AnalyticsService.instance.logEvent('onboarding_names_entered');
                          widget.onNext();
                        },
                        backgroundColor: cs.primary,
                        depthColor: cs.primary.withValues(alpha: 0.8),
                        radius: 16,
                        height: 56,
                        sfxType: DuoSfxType.positive,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Continue",
                              style: TextStyle(
                                fontSize: 16,
                                color: cs.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 20,
                              color: cs.onSurface,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isKeyboardVisible ? 24 : 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

