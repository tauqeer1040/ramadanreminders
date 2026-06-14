import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audiotags/audiotags.dart';
import 'onboarding_data.dart';
import '../../services/audio_service.dart';
import '../widgets/duo_button.dart';
import '../widgets/commitment_button.dart';
import '../../theme/app_theme.dart';

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

class AgePhonePage extends StatefulWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const AgePhonePage({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  State<AgePhonePage> createState() => _AgePhonePageState();
}

class _AgePhonePageState extends State<AgePhonePage> {
  int _age = 25;
  double _phoneHours = 4;
  int _stepIndex = 0; // 0: Ask ready, 1: Million dollars, 2: Wake up, 3: Conclusion, 4: Phone hours
  bool _chosenHard = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.age != null) _age = widget.data.age!;
    if (widget.data.phoneHours != null) {
      _phoneHours = widget.data.phoneHours!.toDouble();
    }
  }

  void _handleBack() {
    if (_stepIndex == 0) {
      widget.onBack();
    } else if (_stepIndex == 4) {
      if (_chosenHard) {
        setState(() => _stepIndex = 3);
      } else {
        setState(() => _stepIndex = 0);
      }
    } else {
      setState(() => _stepIndex--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildCurrentStep(cs, tt),
      ),
    );
  }

  Widget _buildCurrentStep(ColorScheme cs, TextTheme tt) {
    switch (_stepIndex) {
      case 0:
        return _buildReadyStep(cs, tt);
      case 1:
        return _buildMillionDollarsStep(cs, tt);
      case 2:
        return _buildWakeUpStep(cs, tt);
      case 3:
        return _buildConclusionStep(cs, tt);
      case 4:
        return _buildPhoneHoursStep(cs, tt);
      default:
        return _buildReadyStep(cs, tt);
    }
  }

  Widget _buildReadyStep(ColorScheme cs, TextTheme tt) {
    final catName = widget.data.catName;
    final userName = widget.data.displayName;
    return Column(
      key: const ValueKey('ready_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        Text(
          "Are you ready for a deep reflection${userName != null ? ", $userName" : ""}?",
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          "A moment of honest clarity can sometimes bring the most beautiful insights. Are you ready for a hard question${userName != null ? ", $userName" : ""}?",
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.8),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        DuoButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _chosenHard = true;
              _stepIndex = 1;
            });
          },
          backgroundColor: cs.primary,
          depthColor: cs.primary.withValues(alpha: 0.8),
          radius: 16,
          height: 56,
          sfxType: DuoSfxType.positive,
          child: Text(
            "I'm ready${catName != null ? ", $catName" : ""}",
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        DuoButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() {
              _chosenHard = false;
              _stepIndex = 4;
            });
          },
          backgroundColor: cs.secondaryContainer,
          depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
          radius: 16,
          height: 56,
          sfxType: DuoSfxType.negative,
          child: Text(
            "No hard questions today, please",
            style: TextStyle(
              fontSize: 16,
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
                onPressed: _handleBack,
                backgroundColor: cs.secondaryContainer,
                depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                radius: 16,
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
          ],
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildMillionDollarsStep(ColorScheme cs, TextTheme tt) {
    return Column(
      key: const ValueKey('million_dollars_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        Image.asset(
          'assets/photos/elements/money-bag_1f4b0.webp',
          height: 120,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 24),
        Text(
          "First, take a gentle breath and imagine...",
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          "If someone offered you 10 million dollars right now, would you take it?",
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.8),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(flex: 1),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: DuoButton(
                onPressed: _handleBack,
                backgroundColor: cs.secondaryContainer,
                depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                radius: 16,
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
                  HapticFeedback.lightImpact();
                  setState(() => _stepIndex = 2);
                },
                backgroundColor: cs.primary,
                depthColor: cs.primary.withValues(alpha: 0.8),
                radius: 16,
                sfxType: DuoSfxType.positive,
                child: Text(
                  "Yeah!",
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

  Widget _buildWakeUpStep(ColorScheme cs, TextTheme tt) {
    return Column(
      key: const ValueKey('wakeup_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        Image.asset(
          'assets/photos/elements/hourglass-done_231b.webp',
          height: 120,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 24),
        Text(
          "There's one catch though...",
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          "You don't get to wake up tomorrow morning. Your time here ends tonight. The 10 million is yours — but so is that.\n\nWould you still take it?",
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.8),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(flex: 1),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: DuoButton(
                onPressed: _handleBack,
                backgroundColor: cs.secondaryContainer,
                depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                radius: 16,
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
                  HapticFeedback.lightImpact();
                  setState(() => _stepIndex = 3);
                },
                backgroundColor: cs.primary,
                depthColor: cs.primary.withValues(alpha: 0.8),
                radius: 16,
                sfxType: DuoSfxType.positive,
                child: Text(
                  "Nah!",
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

  Widget _buildConclusionStep(ColorScheme cs, TextTheme tt) {
    final name = widget.data.displayName ?? 'friend';
    return Column(
      key: const ValueKey('conclusion_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        Text(
          "Exactly!",
          style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          "Waking up tomorrow is worth more than 10 million dollars!\n\nStarting today $name, We'll try to make the most of every single day. Spend each one mindfully. Journal what's in your heart, here. Nurturing the good in you. Not letting the bitter in you grow, Reflecting on it before Allah.\n\nThis is your promise — to yourself and to Allah.",
          style: tt.bodyLarge?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.8),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        CommitmentButton(
          onCommit: () {
            HapticFeedback.mediumImpact();
            setState(() => _stepIndex = 4);
          },
          color: AppTheme.starGold,
          size: 144,
        ),
        const Spacer(flex: 1),
        Row(
          children: [
            Expanded(
              child: DuoButton(
                onPressed: _handleBack,
                backgroundColor: cs.secondaryContainer,
                depthColor: cs.secondaryContainer.withValues(alpha: 0.8),
                radius: 16,
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
          ],
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildPhoneHoursStep(ColorScheme cs, TextTheme tt) {
    return Column(
      key: const ValueKey('phone_hours_step'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 1),
        Text(
          "How many hours do you spend on your phone daily${widget.data.displayName != null ? " ${widget.data.displayName}" : ""}?",
          style: tt.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          "${_phoneHours.toInt()} hrs/day",
          style: tt.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
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
                onPressed: _handleBack,
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
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  widget.data.age = _age;
                  widget.data.phoneHours = _phoneHours.toInt();
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
        const SizedBox(height: 48),
      ],
    );
  }
}

class BombshellPage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BombshellPage({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) =>
      BombshellPage1(data: data, onNext: onNext, onBack: onBack);
}

// Step 5a — "Did you know?" — monthly phone time
class BombshellPage1 extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BombshellPage1({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final phoneHours = data.phoneHours ?? 4;
    final yearlyHours = phoneHours * 365;
    final yearlyDays = yearlyHours / 24;
    final name = data.displayName;

    // Express as months or years of continuous use
    final String timeLabel;
    if (yearlyDays >= 365) {
      final yrs = (yearlyDays / 365).toStringAsFixed(1);
      timeLabel = '$yrs years';
    } else if (yearlyDays >= 30) {
      final months = (yearlyDays / 30).round();
      timeLabel = '$months months';
    } else {
      timeLabel = '${yearlyDays.round()} days';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 32),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/photos/elements/exploding-head_1f92f.webp',
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                        children: [
                          if (name != null) TextSpan(text: '$name, '),
                          const TextSpan(text: 'You spend the equivalent of\n'),
                          TextSpan(
                            text: '$timeLabel a year',
                            style: const TextStyle(
                              color: AppTheme.starGold,
                              fontSize: 40,
                            ),
                          ),
                          const TextSpan(text: '\n nonstop on your phone.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'non-stop. back to back. every year.',
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                            height: 56,
                            sfxType: DuoSfxType.negative,
                            child: Text(
                              'Back',
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
                            height: 56,
                            sfxType: DuoSfxType.positive,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue',
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
                    const SizedBox(height: 48),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Step 5b — shocking "years of your life" reveal
class BombshellPage2 extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BombshellPage2({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final phoneHours = data.phoneHours ?? 4;
    // average life expectancy ~72, awake ~16hrs/day
    final yearsOnPhone = ((phoneHours / 16) * 72).round();
    final name = data.displayName;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 32),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/photos/elements/skull.webp',
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                        children: [
                          if (name != null) TextSpan(text: '$name, '),
                          const TextSpan(
                            text: 'At this rate you\'re going to spend\n',
                          ),
                          TextSpan(
                            text: '$yearsOnPhone years of your life',
                            style: const TextStyle(
                              color: AppTheme.starGold,
                              fontSize: 40,
                            ),
                          ),
                          const TextSpan(text: '\non your phone.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'that\'s ${yearsOnPhone * 365} days — gone.',
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                            height: 56,
                            sfxType: DuoSfxType.negative,
                            child: Text(
                              'Back',
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
                            height: 56,
                            sfxType: DuoSfxType.positive,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue',
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
                    const SizedBox(height: 48),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Step 5c — positive pivot: Quran reading potential
class BombshellPage3 extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BombshellPage3({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final phoneHours = data.phoneHours ?? 4;
    // 10% of daily phone time in minutes, average Quran reading ~1 page/min
    final dailyMinutes = (phoneHours * 60 * 0.10).round();
    // Quran = 604 pages, reading ~1 page/min
    final daysToFinishQuran = (604 / dailyMinutes).ceil();
    final name = data.displayName;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 32),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/photos/mascot/reading.png',
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                          fontSize: 32,
                        ),
                        children: [
                          // if (name != null) TextSpan(text: '$name, '),
                          const TextSpan(
                            text: "With Meowmin, You could be reading\n",
                          ),
                          const TextSpan(
                            text: '300% more Quran\n',
                            style: TextStyle(color: AppTheme.starGold),
                          ),
                          const TextSpan(text: "in just \n"),
                          const TextSpan(
                            text: '2 minutes a day.',
                            style: TextStyle(color: AppTheme.starGold),
                          ),
                          // const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Spend just 1 minute a day writing your diary, and 1 minute reading verses and stories from the Quran related to what you journal about. It’s a practical start that naturally gets you reflecting on your day through the Quran far more than before.',
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                            height: 56,
                            sfxType: DuoSfxType.negative,
                            child: Text(
                              'Back',
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
                            height: 56,
                            sfxType: DuoSfxType.positive,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Let's do this",
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
                    const SizedBox(height: 48),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BridgePage extends StatelessWidget {
  final OnboardingData data;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const BridgePage({
    required this.data,
    required this.onNext,
    required this.onBack,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 32),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image.asset(
                    //   'assets/photos/elements/meowmin.webp',
                    //   height: 120,
                    //   fit: BoxFit.contain,
                    // ),
                    // const SizedBox(height: 32),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: tt.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                          fontSize: 32,
                        ),
                        children: [
                          const TextSpan(text: "Your Life"),
                          const TextSpan(text: "\n+\n"),
                          const TextSpan(text: "The Holy Quran,\n"),
                          const TextSpan(
                            text: "finally connected!",
                            style: TextStyle(color: AppTheme.starGold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Most people read the Quran without ever connecting it to their daily life. Meowmin builds you a custom plan — you journal what's on your heart, and we pair it with Quran verses and reflections that speak directly to your situation. It's a personal roadmap designed around your life, your struggles, and your growth.",
                      style: tt.bodyLarge?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                            height: 56,
                            sfxType: DuoSfxType.negative,
                            child: Text(
                              'Back',
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
                            height: 56,
                            sfxType: DuoSfxType.positive,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Start my plan",
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
                    const SizedBox(height: 48),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
