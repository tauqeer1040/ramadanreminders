import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/audio_service.dart';
import '../../services/sfx_service.dart';
import '../../theme/app_theme.dart';

class MascotGreeting extends StatefulWidget {
  final String displayName;
  final int streakCount;
  final String? customMessage;

  const MascotGreeting({
    required this.displayName,
    required this.streakCount,
    this.customMessage,
  });

  @override
  State<MascotGreeting> createState() => _MascotGreetingState();
}

class _MascotGreetingState extends State<MascotGreeting>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  late Animation<double> _floatAnim;
  late String _currentMessage;
  static const _bubbleAsset = 'assets/chatbubbles/1 (3).png';

  static const _messageTemplates = [
    'Hey {name}, how are we feeling today?',
    'Hey {name}, I had a busy day! I caught a mouse and made you your scratch cards, take a look!',
    "Masha'Allah {name}, you're on a {streak}-day streak! Keep it going!",
    'Purring while I wait for you to write in your journal, {name}.',
    'Ready for today\'s reflection, {name}?',
    '{name}, the stars are aligned for a beautiful day ahead.',
    'Meow! Let\'s make today amazing, {name}!',
    'I\'ve been working on special insights just for you, {name}!',
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    _pickRandomMessage();
  }

  void _pickRandomMessage() {
    final template =
        _messageTemplates[Random().nextInt(_messageTemplates.length)];
    _currentMessage = template
        .replaceAll('{name}', widget.displayName)
        .replaceAll('{streak}', '${widget.streakCount}');
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: child,
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _pickRandomMessage());
              },
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(_bubbleAsset),
                    fit: BoxFit.fill,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(44, 34, 44, 58),
                  child: Text(
                    widget.customMessage ?? _currentMessage,
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(
                      color: AppTheme.starWhite,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.neonPurple.withValues(alpha: 0.25),
                      AppTheme.neonPurple.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  BackgroundMusicService().toggleMusic();
                  SfxService().toggleSfx();
                },
                child: Image.asset(
                  'assets/photos/mascot/hi.webp',
                  width: 216,
                  height: 216,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.auto_awesome_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 80,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
