import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:scratcher/scratcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/insight_service.dart';
import '../services/favorites_service.dart';
import '../services/shop_service.dart';
import '../core/constants.dart';
import './reflect_card.dart';
import './insight_card_shimmer.dart';
import './favorites_page.dart';
import 'widgets/mascot_empty_state.dart';
import '../utils/image_urls.dart';
import '../screens/about_screen.dart';
import '../theme/app_theme.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

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
  ];

  bool _isLoading = true;
  bool _playing = false;
  String? _error;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Ayah State
  String arabic = '';
  String transliteration = '';
  String english = '';
  String surah = '';
  int ayahNumber = 0;
  String audioUrl = '';

  final AudioPlayer _player = AudioPlayer();
  String _preparedUrl = '';

  List<InsightCard> _insightCards = [];

  final CardSwiperController _swiperController = CardSwiperController();

  // The deck of widgets dynamically built
  List<Widget> _deck = [];
  final Set<int> _revealedCards = {};
  List<String> _scratchCardImages = [];
  final List<_HeartBurst> _hearts = [];
  late String _revealedKey;

  late AnimationController _wobbleCtrl;
  late CurvedAnimation _wobbleAnim;
  Timer? _wobbleTimer;

  @override
  void initState() {
    super.initState();
    _player.setPlayerMode(PlayerMode.mediaPlayer);

    _revealedKey = 'quran_revealed_${DateTime.now().toIso8601String().substring(0, 10)}';
    _initScratchImages();
    _loadPurchasedScratchImages();
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

    _wobbleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _wobbleAnim = CurvedAnimation(
      parent: _wobbleCtrl,
      curve: Curves.easeInOutSine,
    );
    _wobbleTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _wobbleCtrl.forward(from: 0),
    );
  }

  @override
  void dispose() {
    _wobbleCtrl.dispose();
    _wobbleTimer?.cancel();
    _swiperController.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    // 1. Instantly load from cache
    await _loadInsightLocallyOnly();
    await _loadAyahLocallyOnly();

    // 2. Build initial deck and clear loading state immediately
    _buildDeck();
    if (mounted) setState(() => _isLoading = false);

    // 3. Silently fetch fresh data in background from proxy
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

  Future<void> _loadAyahLocallyOnly() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('ayah_data');

    if (cachedData != null) {
      try {
        final data = jsonDecode(cachedData);
        if (mounted) {
          setState(() {
            arabic = data['arabic'] ?? '';
            transliteration = data['transliteration'] ?? '';
            english = data['english'] ?? '';
            surah = data['surah'] ?? '';
            ayahNumber = data['ayahNumber'] ?? 0;
            audioUrl = data['audioUrl'] ?? '';
          });

          if (audioUrl.isNotEmpty && _preparedUrl != audioUrl) {
            _player.setSourceUrl(audioUrl).catchError((_) {});
            _preparedUrl = audioUrl;
          }
        }
      } catch (_) {}
    } else {
      // Fallback offline Ayah if totally fresh install to prevent empty UI
      if (mounted) {
        setState(() {
          arabic = "بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ";
          transliteration = "Bismillaahir Rahmaanir Raheem";
          english =
              "In the name of Allah, the Entirely Merciful, the Especially Merciful.";
          surah = "Al-Fatihah";
          ayahNumber = 1;
        });
      }
    }
  }

  Future<void> _fetchFreshDataSilently() async {
    // 1. Fetch personalized AI insight cards from V2 Backend
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

    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final cachedDate = prefs.getString('ayah_date');

      // V2 Turso Backend URL
      final baseUrl = AppConstants.backendUrl;
      
      // Step A: Priority - Use AI suggested verse from the latest insight
      if (_insightCards.isNotEmpty) {
        final ref = _insightCards.first.reference;
        if (ref.contains(':')) { // Looks like a verse reference
           final res = await http.get(Uri.parse('$baseUrl/ayah?ref=$ref')).timeout(const Duration(seconds: 5));
           if (res.statusCode == 200) {
             final data = jsonDecode(res.body);
             if (mounted) {
               setState(() {
                 arabic = data['arabic'];
                 transliteration = data['transliteration'];
                 english = data['english'];
                 surah = data['surah'];
                 ayahNumber = data['ayahNumber'];
                 audioUrl = data['audioUrl'] ?? '';
                 _buildDeck(); 
               });
               if (audioUrl.isNotEmpty && _preparedUrl != audioUrl) {
                 _player.setSourceUrl(audioUrl).catchError((_) {});
                 _preparedUrl = audioUrl;
               }
             }
             // Cache it even if it's personalized
             await prefs.setString('ayah_date', today);
             await prefs.setString('ayah_data', res.body);
             return; 
           }
        }
      }

      // Step B: Fallback - Random Ayah (if not already fetched today)
      if (cachedDate == today) return;

      final res = await http.get(Uri.parse('$baseUrl/ayah?ref=random')).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (mounted) {
          setState(() {
            arabic = data['arabic'];
            transliteration = data['transliteration'];
            english = data['english'];
            surah = data['surah'];
            ayahNumber = data['ayahNumber'];
            audioUrl = data['audioUrl'];
            _buildDeck(); // Seamlessly rebuild deck with new data
          });

          if (audioUrl.isNotEmpty && _preparedUrl != audioUrl) {
            _player.setSourceUrl(audioUrl).catchError((_) {});
            _preparedUrl = audioUrl;
          }
        }

        // Cache it securely for offline reads
        await prefs.setString('ayah_date', today);
        await prefs.setString('ayah_data', res.body);
      }
    } catch (e) {
      // Silently fail if server offline
    }
  }

  void _initScratchImages() {
    _scratchCardImages = scratchCardUrls()..shuffle();
  }

  Future<void> _loadPurchasedScratchImages() async {
    try {
      final unlocked = await ShopService.getUnlockedIds();
      final purchased = unlocked
          .where((id) {
            final n = int.tryParse(id.split('_').last) ?? 0;
            return n >= 13 && n <= 21;
          })
          .map((id) => shopFullUrl(int.parse(id.split('_').last)))
          .take(3)
          .toList();
      if (purchased.isEmpty || !mounted) return;

      final remaining = scratchCardUrls().where((u) => !purchased.contains(u)).toList();
      setState(() => _scratchCardImages = [...purchased, ...remaining]..shuffle());
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
    if (cardIndex < 0 || cardIndex >= _deck.length) return;
    if (cardIndex < _insightCards.length) {
      final card = _insightCards[cardIndex];
      await FavoritesService.addFavorite(FavoriteItem(
        type: FavoriteType.insight,
        savedAt: DateTime.now(),
        date: card.date,
        greeting: card.greeting,
        insight: card.insight,
        reference: card.reference,
        quote: card.quote,
        tags: card.tags,
      ));
    } else {
      await FavoritesService.addFavorite(FavoriteItem(
        type: FavoriteType.ayah,
        savedAt: DateTime.now(),
        arabic: arabic,
        transliteration: transliteration,
        english: english,
        surah: surah,
        ayahNumber: ayahNumber,
        audioUrl: audioUrl,
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

    // 1. Personalized AI insight cards — one per fetched insight (tag-ranked)
    for (final entry in _insightCards.asMap().entries) {
      final index = entry.key;
      final card = entry.value;
      final theme = _cardColorSchemes[index % _cardColorSchemes.length];
      final pillBg = theme.accent.withValues(alpha: 0.12);

      _deck.add(
        ReflectCard(
          backgroundColor: theme.bg,
          borderColor: theme.text,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: theme.text, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your Journal Insight',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Tag chips
              if (card.tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: card.tags.map((tag) => Chip(
                    label: Text(
                      tag,
                      style: textTheme.labelSmall?.copyWith(
                        color: theme.text,
                      ),
                    ),
                    backgroundColor: pillBg,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              const SizedBox(height: 16),
              Text(
                card.greeting,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                card.insight,
                style: textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: theme.text,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.quote,
                      style: textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                        color: theme.text,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Ayah Card
    final ayahIndex = _insightCards.length;
    final ayahTheme = _cardColorSchemes[ayahIndex % _cardColorSchemes.length];
    final ayahPillBg = ayahTheme.accent.withValues(alpha: 0.12);

    _deck.add(
      ReflectCard(
        backgroundColor: ayahTheme.bg,
        borderColor: ayahTheme.text,
        playButtonColor: ayahTheme.text,
        showPlayButton: true,
        isPlaying: _playing,
        playbackProgress: _duration.inMilliseconds > 0
            ? _position.inMilliseconds / _duration.inMilliseconds
            : 0.0,
        onPlay: () async {
          if (audioUrl.isEmpty) return;
          HapticFeedback.mediumImpact();
          if (_playing) {
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: ayahPillBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: ayahTheme.text),
                ),
              ),
            Text(
              arabic,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontSize: 34,
                height: 1.8,
                fontFamily: 'Amiri',
                color: ayahTheme.text,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              transliteration,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                height: 1.5,
                        color: ayahTheme.text.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '\u201c$english\u201d',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                fontSize: 18,
                height: 1.6,
                fontStyle: FontStyle.italic,
                color: ayahTheme.text,
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: ayahPillBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$surah : $ayahNumber',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: ayahTheme.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: cs.primaryContainer,
                        child: ClipOval(
                          child: Image.asset(
                            'assets/photos/mascot/hi.webp',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome_rounded, color: cs.onSurface, size: 28),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            Superwall.shared.registerPlacement('campaign_trigger');
                          },
                          child: AnimatedBuilder(
                            animation: _wobbleAnim,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: sin(_wobbleAnim.value * 4.5 * 2 * pi) * 0.08,
                                child: child,
                              );
                            },
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
                  height: 520,
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

                                if (!revealed) {
                                  card = ClipRRect(
                                    borderRadius: BorderRadius.circular(32),
                                    child: Stack(
                                      children: [
                                        Scratcher(
                                          brushSize: 30,
                                          threshold: 35,
                                          image: (_scratchCardImages[index % _scratchCardImages.length]).startsWith('http')
                                              ? Image.network(
                                                  _scratchCardImages[index % _scratchCardImages.length],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                                )
                                              : Image.asset(
                                                  _scratchCardImages[index % _scratchCardImages.length],
                                                  fit: BoxFit.cover,
                                                ),
                                          onThreshold: () {
                                            setState(() => _revealedCards.add(index));
                                            _saveRevealedCards();
                                            HapticFeedback.heavyImpact();
                                            _triggerConfetti();
                                            ShopService.addStars(3);
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
  late Animation<Offset> _slideAnim;

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
    _slideAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.4),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // handled by timer in _showHeart
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FractionalTranslation(
          translation: _slideAnim.value,
          child: Opacity(
            opacity: _fadeAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: const Icon(Icons.favorite, size: 80, color: Colors.red),
            ),
          ),
        );
      },
    );
  }
}
