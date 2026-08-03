import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:scratcher/scratcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

import '../services/insight_service.dart';
import '../services/favorites_service.dart';
import '../services/shop_service.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import './reflect_card.dart';
import './insight_card_shimmer.dart';
import './favorites_page.dart';
import 'widgets/mascot_empty_state.dart';
import '../utils/image_urls.dart';
import '../theme/app_theme.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage>
    with SingleTickerProviderStateMixin {
  static const List<_CardColorTheme> _cardColorSchemes = [
    _CardColorTheme(
      bg: Color(0xFFD6DF7E),
      text: Color(0xFF13441A),
      accent: Color(0xFF187B25),
    ),
    _CardColorTheme(
      bg: Color(0xFFFAA49A),
      text: Color(0xFF4E1106),
      accent: Color(0xFFC4391D),
    ),
    _CardColorTheme(
      bg: Color(0xFFA0C4FF),
      text: Color(0xFF00154F),
      accent: Color(0xFF0052FF),
    ),
    _CardColorTheme(
      bg: Color(0xFFFFF0B2),
      text: Color(0xFF4E2E00),
      accent: Color(0xFFA86200),
    ),
  ];

  bool _isLoading = true;
  bool _playing = false;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _purrPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  final AudioPlayer _rewardPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  String _preparedUrl = '';

  List<InsightCard> _insightCards = [];

  final CardSwiperController _swiperController = CardSwiperController();

  // The deck of widgets dynamically built
  List<Widget> _deck = [];
  final Set<int> _revealedCards = {};
  List<String> _scratchCardImages = [];
  final List<_HeartBurst> _hearts = [];
  late String _revealedKey;

  @override
  void initState() {
    super.initState();
    _player.setPlayerMode(PlayerMode.mediaPlayer);

    _revealedKey = 'quran_revealed_${DateTime.now().toIso8601String().substring(0, 10)}';
    _loadRevealedCards();
    _initData();

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playing = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.instance.logQuranOpened();
    });
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _player.dispose();
    _purrPlayer.dispose();
    _rewardPlayer.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    await _initScratchImages();
    await _loadInsightLocallyOnly();

    _buildDeck();
    if (mounted) setState(() => _isLoading = false);

    _fetchFreshDataSilently();
  }


  Future<void> _loadInsightLocallyOnly() async {
    try {
      final cached = await InsightService.loadCacheInternal(); // I'll add this getter
      if (mounted && cached != null && cached.isNotEmpty) {
        setState(() {
          _insightCards = cached;
          _buildDeck();
        });
      }
    } catch (_) {}
  }



  Future<void> _fetchFreshDataSilently() async {
    if (FirebaseAuth.instance.currentUser != null) {
      InsightService.fetchPersonalizedInsights(limit: 3, forceRefresh: true).then((cards) {
        if (mounted && cards.isNotEmpty) {
          setState(() {
            _insightCards = cards;
            _buildDeck();
          });
        }
      });
    }
  }

  Future<void> _initScratchImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlocked = await ShopService.getUnlockedIds();
      final unlockedScratchIds = unlocked.where((id) {
        final n = int.tryParse(id.split('_').last) ?? 0;
        return n >= 13 && n <= 21;
      }).toSet();

      const orderKey = 'quran_scratch_order';
      final persisted = prefs.getStringList(orderKey) ?? [];
      final validOrdered = persisted.where((id) => unlockedScratchIds.contains(id)).toList();
      final existing = validOrdered.toSet();
      final newItems = unlockedScratchIds.where((id) => !existing.contains(id)).toList();

      final order = [...validOrdered, ...newItems];
      final urls = order.map((id) => shopFullUrl(int.parse(id.split('_').last))).toList();

      await prefs.setStringList(orderKey, order);

      if (mounted) setState(() => _scratchCardImages = urls);
    } catch (_) {}
  }

  Future<void> _loadRevealedCards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_revealedKey);
    if (raw != null) {
      setState(() {
        _revealedCards.addAll(raw.map(int.parse).toSet());
      });
    }
  }

  Future<void> _saveRevealedCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _revealedKey,
      _revealedCards.map((e) => e.toString()).toList(),
    );
  }

  void _showHeart() {
    final burst = _HeartBurst();
    setState(() => _hearts.add(burst));
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _hearts.remove(burst));
    });
  }

  void _favoriteCurrentInsight(int cardIndex) async {
    if (cardIndex < 0 || cardIndex >= _insightCards.length) return;
    final card = _insightCards[cardIndex];
    if (card.type == 'surah_guidance') {
      await FavoritesService.addFavorite(FavoriteItem(
        type: FavoriteType.ayah,
        savedAt: DateTime.now(),
        arabic: card.arabicVerse,
        transliteration: card.transliteration,
        english: card.english,
        surah: card.surahName,
        ayahNumber: card.ayahNumber,
        audioUrl: card.audioUrl,
      ));
    } else {
      await FavoritesService.addFavorite(FavoriteItem(
        type: FavoriteType.insight,
        savedAt: DateTime.now(),
        date: card.date,
        insight: card.type == 'personalized_insight'
            ? card.insight
            : '${card.story ?? ''}\n\n${card.lesson ?? ''}',
        reference: card.reference ?? card.storyReference,
      ));
    }
  }

  void _triggerConfetti() {
    Confetti.launch(
      context,
      options: ConfettiOptions(
        particleCount: 40,
        spread: 60,
        y: 0.5,
      ),
    );
  }


  void _buildDeck() {
    _deck = [];
    final textTheme = Theme.of(context).textTheme;

    for (final entry in _insightCards.asMap().entries) {
      final index = entry.key;
      final card = entry.value;
      final theme = _cardColorSchemes[index % _cardColorSchemes.length];
      final pillBg = theme.accent.withValues(alpha: 0.12);

      Widget cardContent;
      switch (card.type) {
        case 'personalized_insight':
          cardContent = _buildPersonalizedInsightCard(card, theme, pillBg, textTheme);
        case 'surah_guidance':
          cardContent = _buildSurahGuidanceCard(card, theme, pillBg, textTheme);
          final audioUrl = card.audioUrl ?? '';
          _deck.add(
            ReflectCard(
              backgroundColor: theme.bg,
              borderColor: theme.text,
              showPlayButton: audioUrl.isNotEmpty,
              playButtonColor: theme.text,
              isPlaying: _playing && _preparedUrl == audioUrl,
              playbackProgress: _duration.inMilliseconds > 0
                  ? _position.inMilliseconds / _duration.inMilliseconds
                  : 0.0,
              onPlay: () async {
                if (audioUrl.isEmpty) return;
                HapticFeedback.mediumImpact();
                if (_playing && _preparedUrl == audioUrl) {
                  await _player.pause();
                } else {
                  try {
                    if (_preparedUrl != audioUrl || _position == Duration.zero) {
                      await _player.play(UrlSource(audioUrl));
                      _preparedUrl = audioUrl;
                    } else {
                      await _player.resume();
                    }
                  } catch (e) {
                    await _player.play(UrlSource(audioUrl));
                    _preparedUrl = audioUrl;
                  }
                }
              },
              child: cardContent,
            ),
          );
        case 'story_and_task':
          cardContent = _buildStoryTaskCard(card, theme, pillBg, textTheme);
          _deck.add(
            ReflectCard(
              backgroundColor: theme.bg,
              borderColor: theme.text,
              child: cardContent,
            ),
          );
        default:
          cardContent = _buildPersonalizedInsightCard(card, theme, pillBg, textTheme);
          _deck.add(
            ReflectCard(
              backgroundColor: theme.bg,
              borderColor: theme.text,
              child: cardContent,
            ),
          );
      }
    }
  }

  Widget _faceAvatar(_CardColorTheme theme, {double size = 32}) {
    return ClipOval(
      child: Image.asset(
        'assets/photos/mascot/face.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome, color: theme.text, size: size * 0.8),
      ),
    );
  }

  Widget _buildPersonalizedInsightCard(InsightCard card, _CardColorTheme theme, Color pillBg, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/photos/mascot/face.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome, color: theme.text, size: 26),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                card.insight ?? '',
                style: textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: theme.text,
                ),
              ),
            ),
          ],
        ),
        if (card.journalExcerpt != null && card.journalExcerpt!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.text.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.format_quote, size: 18, color: theme.text.withValues(alpha: 0.5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '"${card.journalExcerpt}"',
                    style: textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                      color: theme.text.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (card.quote != null && card.quote!.isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.quote!,
                  style: textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                    color: theme.text,
                  ),
                ),
                if (card.reference != null && card.reference!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '— ${card.reference}',
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSurahGuidanceCard(InsightCard card, _CardColorTheme theme, Color pillBg, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (card.arabicVerse != null && card.arabicVerse!.isNotEmpty) ...[
          Text(
            card.arabicVerse!,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 30,
              height: 1.7,
              fontFamily: 'Amiri',
              color: theme.text,
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (card.transliteration != null && card.transliteration!.isNotEmpty) ...[
          Text(
            card.transliteration!,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              height: 1.4,
              color: theme.text.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (card.english != null && card.english!.isNotEmpty) ...[
          Text(
            '\u201c${card.english}\u201d',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              height: 1.5,
              fontStyle: FontStyle.italic,
              color: theme.text,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (card.surahName != null && card.ayahNumber != null) ...[
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${card.surahName} : ${card.ayahNumber}',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.text,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (card.explanation != null && card.explanation!.isNotEmpty) ...[
          Divider(color: pillBg, thickness: 1),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _faceAvatar(theme),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  card.explanation!,
                  style: textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: theme.text,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStoryTaskCard(InsightCard card, _CardColorTheme theme, Color pillBg, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card.story != null && card.story!.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _faceAvatar(theme),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  card.story!,
                  style: textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: theme.text,
                  ),
                ),
              ),
            ],
          ),
          if (card.storyReference != null && card.storyReference!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '— ${card.storyReference}',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  color: theme.text.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
        if (card.lesson != null && card.lesson!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.text.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _faceAvatar(theme, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    card.lesson!,
                    style: textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: theme.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (card.taskTitle != null && card.taskTitle!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.text.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.text.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.check_circle_outline, color: theme.text, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        card.taskTitle!,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.text,
                        ),
                      ),
                      if (card.taskDescription != null && card.taskDescription!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          card.taskDescription!,
                          style: textTheme.bodySmall?.copyWith(
                            height: 1.4,
                            color: theme.text.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }


  Future<bool> _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) async {
    HapticFeedback.lightImpact();
    // If the Ayah card was swiped, optionally fetch a new one
    // We are implementing looping, so they can keep swiping it.
    // Let's just allow it completely
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Always rebuild deck for play progress updates (unless still loading)
    if (!_isLoading) _buildDeck();

    // To ensure the swiper can loop indefinitely, if we only have 1 card
    // we duplicate it so that cardsCount is at least 2.
    if (_deck.length == 1) {
      _deck.add(_deck.first);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar: Avatar · Logo · Favorites ──────────────────────────
            SizedBox(
              height: 128,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        BackgroundMusicService().toggleMusic();
                        if (context.mounted) setState(() {});
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          if (BackgroundMusicService().isMusicEnabled)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                child: Transform.scale(
                                  scale: 2,
                                  alignment: Alignment.bottomCenter,
                                  child: Lottie.asset('assets/photos/elements/Music fly.json', fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: cs.primaryContainer,
                            child: ClipOval(
                              child: Image.asset(
                                'assets/photos/mascot/face.png',
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, color: cs.onSurface, size: 28),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: () {},
                        child: Image.asset(
                          'assets/photos/elements/meowmin.png',
                          width: 120,
                          height: 80,
                          fit: BoxFit.contain,
                        ).animate().shimmer(
                          duration: 2500.ms,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FavoritesPage()),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.starGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: AppTheme.starGold,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: 620,
                  child: _isLoading
                      ? const InsightCardShimmer()
                      : _deck.isNotEmpty
                          ? CardSwiper(
                              controller: _swiperController,
                              cardsCount: _deck.length,
                              numberOfCardsDisplayed: _deck.length > 1 ? 2 : 1,
                              onSwipe: _onSwipe,
                              isLoop: true,
                              cardBuilder: (
                                context,
                                index,
                                percentThresholdX,
                                percentThresholdY,
                              ) {
                                final revealed = _revealedCards.contains(index);
                                Widget card = _deck[index];

                                if (!revealed && _scratchCardImages.isNotEmpty) {
                                  final scratchImage = _scratchCardImages[index % _scratchCardImages.length];
                                  card = ClipRRect(
                                    borderRadius: BorderRadius.circular(32),
                                    child: Stack(
                                      children: [
                                        Scratcher(
                                          brushSize: 30,
                                          threshold: 35,
                                          image: scratchImage.startsWith('http')
                                              ? Image.network(
                                                  scratchImage,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                                )
                                              : Image.asset(
                                                  scratchImage,
                                                  fit: BoxFit.cover,
                                                ),
                                          onScratchStart: () {
                                            HapticFeedback.mediumImpact();
                                            _purrPlayer.setReleaseMode(ReleaseMode.loop);
                                            _purrPlayer.play(AssetSource('tunes/sfx/cat_purr.mp3'));
                                          },
                                          onScratchEnd: () {
                                            _purrPlayer.stop();
                                          },
                                          onThreshold: () {
                                            _purrPlayer.stop();
                                            setState(() => _revealedCards.add(index));
                                            _saveRevealedCards();
                                            HapticFeedback.heavyImpact();
                                            _triggerConfetti();
                                            _rewardPlayer.play(AssetSource('tunes/positive_tone_a6b6.wav'));
                                            ShopService.awardStars('quran_read');
                                          },
                                          child: card,
                                        ),
                                        IgnorePointer(
                                          child: Shimmer.fromColors(
                                            baseColor: Colors.transparent,
                                            highlightColor: Colors.white.withValues(alpha: 0.25),
                                            period: const Duration(milliseconds: 2000),
                                            child: Container(color: Colors.black),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  card = ClipRRect(
                                    borderRadius: BorderRadius.circular(32),
                                    child: GestureDetector(
                                      onDoubleTapDown: (details) {
                                        _showHeart();
                                        _favoriteCurrentInsight(index);
                                        HapticFeedback.mediumImpact();
                                      },
                                      child: Stack(
                                        children: [
                                          card,
                                          for (final heart in _hearts)
                                            IgnorePointer(
                                              child: _HeartWidget(heart: heart),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                return card;
                              },
                            )
                          : const MascotEmptyState(
                              message: 'Start journaling to unlock\nyour daily insight cards.',
                              actionLabel: 'Write a journal entry',
                            ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _CardColorTheme {
  final Color bg;
  final Color text;
  final Color accent;
  const _CardColorTheme({
    required this.bg,
    required this.text,
    required this.accent,
  });
}

class _HeartBurst {
  final DateTime createdAt = DateTime.now();
}

class _HeartWidget extends StatefulWidget {
  final _HeartBurst heart;
  const _HeartWidget({required this.heart});

  @override
  State<_HeartWidget> createState() => _HeartWidgetState();
}

class _HeartWidgetState extends State<_HeartWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: const Icon(Icons.favorite, size: 80, color: Colors.red),
            ),
          );
        },
      ),
    );
  }
}


