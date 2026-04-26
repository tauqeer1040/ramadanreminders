import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';



import '../services/insight_service.dart';
import '../core/constants.dart';
import './journal_section.dart';
import './reflect_card.dart';
import './insight_card_shimmer.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  static const List<String> _insightFrameImages = [
    'assets/photos/images/ethreialbloom1.jpeg',
    'assets/photos/images/EtherealFlower.jpeg',
    'assets/photos/images/DelicateOrangeFlowerinBloom.jpeg',
    'assets/photos/images/EtherealFlower-1-.jpeg',
    'assets/photos/images/Delicate Translucent Flower.png',
    'assets/photos/images/Ethereal Flower in Motion.png',
    'assets/photos/images/Ethereal Glowing Flower.png',
    'assets/photos/images/Radiant Flower Glow.png',
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

  @override
  void initState() {
    super.initState();
    _player.setPlayerMode(PlayerMode.mediaPlayer);

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
  }

  @override
  void dispose() {
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

  String _frameImageForInsight(InsightCard card, int index) {
    final seed = '${card.date}|${card.reference}|$index'.hashCode;
    final normalized = seed.abs() % _insightFrameImages.length;
    return _insightFrameImages[normalized];
  }

  void _buildDeck() {
    _deck = [];
    final textTheme = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    // 1. Personalized AI insight cards — one per fetched insight (tag-ranked)
    for (final entry in _insightCards.asMap().entries) {
      final index = entry.key;
      final card = entry.value;
      _deck.add(
        ReflectCard(
          frameImageAsset: _frameImageForInsight(card, index),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: cs.primary, size: 26),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your Journal Insight',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
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
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                    backgroundColor: cs.secondaryContainer,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              const SizedBox(height: 16),
              Text(
                card.greeting,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                card.insight,
                style: textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
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
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '— ${card.reference}',
                        style: textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onTertiaryContainer,
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
    _deck.add(
      ReflectCard(
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
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: cs.onErrorContainer),
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
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              transliteration,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                height: 1.5,
                color: cs.secondary,
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
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$surah : $ayahNumber',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSecondaryContainer,
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
      backgroundColor: cs.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Daily Reflection',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: cs.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const JournalSection(),
            Expanded(
              child: _isLoading
                  // Shimmer skeleton — mirrors the real card shape exactly
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: InsightCardShimmer(),
                    )
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
                            return _deck[index];
                          },
                        )
                      : const Center(child: Text("No cards available")),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
