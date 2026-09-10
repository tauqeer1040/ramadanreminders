import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../services/growth_prompt_service.dart';
import 'package:scratcher/scratcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_confetti/flutter_confetti.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/app_background.dart';
import '../services/insight_service.dart';
import '../services/deck_rotation_service.dart';
import '../services/moment_paywall_service.dart';
import '../services/deck_queue_logic.dart';
import 'widgets/deferred_lottie.dart';
import '../services/favorites_service.dart';
import '../services/shop_service.dart';
import '../services/analytics_service.dart';
import '../services/audio_service.dart';
import '../services/story_share_service.dart';
import './reflect_card.dart';
import './favorites_page.dart';
import 'widgets/delight_action_sheet.dart';
import 'widgets/share_insight_sheet.dart';
import 'widgets/mascot_empty_state.dart';
import '../utils/image_urls.dart';
import '../theme/app_theme.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
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

  // Screenshot offers only fire while the app is foregrounded and this tab
  // is the visible page (see _offerShare).
  bool _isAppResumed = true;

  // Keep state alive when the tab scrolls out of the PageView cache extent.
  // Without this, each tab toggle disposes QuranPage and recreates it —
  // re-running initState (deck reload, screenshot listener, audio init).
  @override
  bool get wantKeepAlive => true;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final AudioPlayer _player = AudioPlayer();
  final AudioPlayer _purrPlayer = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency);
  final AudioPlayer _rewardPlayer = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency);
  String _preparedUrl = '';

  List<InsightCard> _insightCards = [];
  String? _deckId;
  int _queueDepth = 0;

  bool get _fullyRevealed => isDeckFullyRevealed(
    _insightCards.map((c) => c.id ?? '').toSet(),
    _revealedCards,
  );

  final CardSwiperController _swiperController = CardSwiperController();
  final ScreenshotController _shotController = ScreenshotController();

  // Top card index (tracked via onSwipe) + per-card share throttle: each
  // card offers the share sheet at most once per page session.
  int _topIndex = 0;
  final Set<String> _shareOfferedCardKeys = {};

  // The deck of widgets dynamically built
  List<Widget> _deck = [];
  final Set<String> _revealedCards = {};
  // Scratch overlays render only after reveal-state has loaded from prefs —
  // text-first is the safe default. Without this, any paint before prefs
  // resolve shows unsratched AND pre-scratched cards with faces (flash).
  bool _revealedLoaded = false;
  List<String> _scratchCardImages = [];
  final List<_HeartBurst> _hearts = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player.setPlayerMode(PlayerMode.mediaPlayer);

    _initData();

    // Offer story-sharing when the OS reports a screenshot of this page.
    // Native side: Android 14+ ScreenCaptureCallback, iOS screenshot
    // notification. Older Android has no detector (like-trigger still works).
    StoryShareService.listenForScreenshots(_onDeviceScreenshot);

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _swiperController.dispose();
    StoryShareService.stopListeningForScreenshots();
    _player.dispose();
    _purrPlayer.dispose();
    _rewardPlayer.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    // Revealed IDs must load BEFORE the deck builds. If the deck paints
    // first, already-scratched cards briefly show the scratch face and
    // then swap to text (the launch flash).
    await _loadRevealedCards();
    await _initScratchImages();
    await _loadInsightLocallyOnly();

    _buildDeck();
    if (mounted) setState(() => _isLoading = false);

    _syncDecksSilently();
  }

  Future<void> _loadInsightLocallyOnly() async {
    try {
      // Client-side rotation first: cached AI decks, newest-first, looping,
      // max 3 deck changes per local day (cycles today's 3 after the cap).
      final rotated = await DeckRotationService.currentDeckForLaunch(
        revealedCardIds: _revealedCards,
        currentCards: const [],
      );
      if (mounted && rotated != null && rotated.cards.isNotEmpty) {
        setState(() {
          _deckId = rotated.deckId;
          _insightCards = rotated.cards;
          _queueDepth = rotated.queueDepth;
          _buildDeck();
        });
        _advanceScratchRotation();
        return;
      }
      // Rotation cache empty (first launch before first sync): fall back to
      // the server's sticky day-deck, then the prefetch buffer, then legacy
      // caches. The post-boot sync (below) rotates onto the cached deck.
      final deck = await InsightService.fetchTodayDeck();
      if (mounted && deck.cards.isNotEmpty) {
        setState(() {
          _deckId = deck.deckId;
          _insightCards = deck.cards;
          _queueDepth = deck.queueDepth;
          _buildDeck();
        });
        if (deck.deckId != null) {
          await DeckRotationService.noteCurrentDeck(deck.deckId!);
        }
        _advanceScratchRotation();
        return;
      }
      // Prefetch buffer: newest lookahead paints instantly (offline launches).
      final buffer = await InsightService.loadDeckBuffer();
      if (mounted && buffer.isNotEmpty) {
        final head = DeckResult(
          deckId: buffer.first['deckId'] as String?,
          journalId: buffer.first['journalId'] as String?,
          cards: (buffer.first['insightCards'] as List? ?? [])
              .map(
                (e) =>
                    InsightCard.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .where((c) => c.type.isNotEmpty)
              .toList(),
        );
        if (head.cards.isNotEmpty) {
          setState(() {
            _deckId = head.deckId;
            _insightCards = head.cards;
            _buildDeck();
          });
          if (head.deckId != null) {
            await DeckRotationService.noteCurrentDeck(head.deckId!);
          }
          _advanceScratchRotation();
          return;
        }
      }
      // Legacy caches: instant paint for upgraders before the first deck fetch.
      final scratchCached = await InsightService.loadScratchCacheInternal();
      final cached = scratchCached ?? await InsightService.loadCacheInternal();
      if (mounted && cached != null && cached.isNotEmpty) {
        setState(() {
          _insightCards = cached;
          _buildDeck();
        });
      }
    } catch (_) {}
  }

  Future<void> _syncDecksSilently() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      // Pull the full deck list into the rotation cache. New decks land at
      // the front (newest-first), so the next launch picks them up first.
      final synced = await DeckRotationService.sync();
      if (synced && mounted) {
        // Adopt the rotation's deck if it differs from what's on screen
        // (e.g. cache was empty at first paint, or this launch had changes
        // left). Protected decks (mid-reveal) come back unchanged.
        final rotated = await DeckRotationService.currentDeckForLaunch(
          revealedCardIds: _revealedCards,
          currentCards: _insightCards,
          currentDeckId: _deckId,
          fullyRevealed: _fullyRevealed,
        );
        if (rotated != null &&
            rotated.cards.isNotEmpty &&
            rotated.deckId != _deckId) {
          final newIds = rotated.cards.map((c) => c.id ?? '').toSet();
          final curIds = _insightCards.map((c) => c.id ?? '').toSet();
          switch (deckSwapAction(
            fetchedDeckId: rotated.deckId,
            fetchedCardIds: newIds,
            currentDeckId: _deckId,
            currentCardIds: curIds,
            revealedCardIds: _revealedCards,
          )) {
            case DeckSwapAction.keep:
            case DeckSwapAction.refreshMetadata:
              break;
            case DeckSwapAction.swap:
              setState(() {
                _deckId = rotated.deckId;
                _insightCards = rotated.cards;
                _queueDepth = rotated.queueDepth;
                _buildDeck();
              });
              _advanceScratchRotation();
              break;
          }
        }
      }
    } catch (_) {
      // Offline or server error: the rotation cache keeps working as-is.
    }
  }



  // Rotation pointer into [_scratchIds]: faces shown per deck advance it,
  // so every unlocked face appears before any repeats. Guarded by deck id
  // so rebuilds mid-scratch never reshuffle.
  List<String> _scratchIds = [];
  int _scratchPos = 0;
  String? _faceDeckId;

  Future<void> _initScratchImages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final unlocked = await ShopService.getUnlockedIds();
      // Every unlocked shop item (flowers 1–12 AND scratch cards 13–21)
      // is an eligible face.
      final unlockedFaces = unlocked.where((id) {
        final n = int.tryParse(id.split('_').last) ?? 0;
        return n >= 1 && n <= 21;
      }).toSet();

      const orderKey = 'quran_scratch_order';
      const posKey = 'quran_scratch_pos';
      const deckKey = 'quran_scratch_deck';
      final persisted = prefs.getStringList(orderKey) ?? [];
      final kept = persisted.where((id) => unlockedFaces.contains(id)).toList();
      final keptSet = kept.toSet();
      final fresh = unlockedFaces.where((id) => !keptSet.contains(id)).toList()
        ..shuffle();
      // Stable order across launches; new unlocks splice into random spots.
      // Never reshuffles behind the user's back (no repeat-until-cycled).
      final order = [...kept];
      final rng = math.Random();
      for (final id in fresh) {
        order.insert(order.isEmpty ? 0 : rng.nextInt(order.length + 1), id);
      }

      var pos = prefs.getInt(posKey) ?? 0;
      if (order.isEmpty) {
        pos = 0;
      } else {
        // Stable pointer across launches; clamped when the set changed.
        pos = pos % order.length;
      }
      _faceDeckId = prefs.getString(deckKey);
      _scratchPos = pos;

      final urls = order
          .map((id) => shopFullUrl(int.parse(id.split('_').last)))
          .toList();

      await prefs.setStringList(orderKey, order);
      await prefs.setInt(posKey, pos);

      if (mounted) {
        setState(() {
          _scratchIds = order;
          _scratchCardImages = urls;
        });
      }
      // Cover cards ASAP (uncovered = spoiler), then decode faces in the
      // background so swipes never flash a stale face.
      for (final url in urls) {
        if (!mounted) return;
        try {
          final provider = url.startsWith('http')
              ? NetworkImage(url)
              : AssetImage(url) as ImageProvider;
          await precacheImage(provider, context);
        } catch (_) {}
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  /// Face url for card position [i]: rotation queue, no repeats until every
  /// unlocked face has been shown. Empty when nothing is unlocked.
  String? _scratchFaceFor(int i) {
    if (_scratchCardImages.isEmpty) return null;
    if (_scratchIds.isEmpty) {
      return _scratchCardImages[i % _scratchCardImages.length];
    }
    return _scratchCardImages[(_scratchPos + i) % _scratchCardImages.length];
  }

  /// Advance the rotation after a new deck is adopted (fire-and-forget).
  /// Reshuffles only on full-cycle wrap, preserving no-repeat-within-cycle.
  void _advanceScratchRotation() {
    final deckId = _deckId;
    if (deckId == null || deckId == _faceDeckId || _scratchIds.isEmpty) return;
    _faceDeckId = deckId;
    final len = _scratchIds.length;
    final step = _insightCards.isEmpty ? 3 : _insightCards.length;
    var pos = (_scratchPos + step) % len;
    if (pos < _scratchPos) {
      // Full cycle completed: reshuffle for a fresh random rotation.
      final order = [..._scratchIds]..shuffle();
      _scratchIds = order;
      _scratchCardImages = order
          .map((id) => shopFullUrl(int.parse(id.split('_').last)))
          .toList();
      pos = 0;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setStringList('quran_scratch_order', order);
        prefs.setInt('quran_scratch_pos', pos);
        if (deckId.isNotEmpty) prefs.setString('quran_scratch_deck', deckId);
      });
    } else {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('quran_scratch_pos', pos);
        if (deckId.isNotEmpty) prefs.setString('quran_scratch_deck', deckId);
      });
    }
    _scratchPos = pos;
    if (mounted) setState(() {});
  }

  Future<void> _loadRevealedCards() async {
    final ids = await InsightService.loadRevealedIds();
    // Migration: also load legacy per-day int indices if present and convert if needed
    // We keep ids as strings; legacy int entries are ignored after first new save.
    if (ids.isNotEmpty) {
      _revealedCards.addAll(ids);
    }
    if (mounted) {
      setState(() => _revealedLoaded = true);
    } else {
      _revealedLoaded = true;
    }
  }

  Future<void> _saveRevealedCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      InsightService.revealedIdsKey,
      _revealedCards.toList(),
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
      await FavoritesService.addFavorite(
        FavoriteItem(
          type: FavoriteType.ayah,
          savedAt: DateTime.now(),
          arabic: card.arabicVerse,
          transliteration: card.transliteration,
          english: card.english,
          surah: card.surahName,
          ayahNumber: card.ayahNumber,
          audioUrl: card.audioUrl,
        ),
      );
    } else {
      await FavoritesService.addFavorite(
        FavoriteItem(
          type: FavoriteType.insight,
          savedAt: DateTime.now(),
          date: card.date,
          insight: card.type == 'personalized_insight'
              ? card.insight
              : '${card.story ?? ''}\n\n${card.lesson ?? ''}',
          reference: card.reference ?? card.storyReference,
        ),
      );
    }
  }

  /// One second after a double-tap like, offer a single rotating
  /// growth action (review/share). Policy — 24h throttle, review at
  /// most once per version (5-star stops forever), share max twice
  /// per week, 7-day snooze — lives in [GrowthPromptService].
  /// Never stacks over another route.
  void _scheduleDelightSheet() {
    Future.delayed(const Duration(seconds: 1), () async {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      try {
        if (!await GrowthPromptService.shouldShowSheet()) return;
        var actionName = await GrowthPromptService.nextActionName();
        var action = switch (actionName) {
          'share' => DelightAction.share,
          'reminders' => DelightAction.reminders,
          _ => DelightAction.review,
        };
        if (action == DelightAction.review) {
          if (kIsWeb || !await GrowthPromptService.shouldOfferReview()) {
            action = DelightAction.share;
          }
        }
        if (action == DelightAction.reminders) {
          // Never offer reminders on web, and never to users who already
          // granted — skip this arm (rotation still advanced below).
          var granted = false;
          try {
            granted = kIsWeb
                ? true
                : await NotificationService.checkPermissions();
          } catch (_) {}
          if (granted) {
            await GrowthPromptService.flipNextAction(action.name);
            return;
          }
        }
        if (action == DelightAction.share &&
            !await GrowthPromptService.shouldOfferShare()) {
          return;
        }
        await GrowthPromptService.flipNextAction(action.name);
        await GrowthPromptService.recordSheetShown();
        if (action == DelightAction.review) {
          await GrowthPromptService.recordReviewOffered();
        }
        if (!mounted) return;
        final routeNow = ModalRoute.of(context);
        if (routeNow != null && !routeNow.isCurrent) return;
        await showDelightActionSheet(context, action);
      } catch (_) {
        // Never interrupt journaling for a growth prompt.
      }
    });
  }

  void _triggerConfetti() {
    Confetti.launch(
      context,
      options: ConfettiOptions(particleCount: 40, spread: 60, y: 0.5),
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
          cardContent = _buildPersonalizedInsightCard(
            card,
            theme,
            pillBg,
            textTheme,
          );
          _deck.add(
            ReflectCard(
              backgroundColor: theme.bg,
              borderColor: theme.text,
              child: cardContent,
            ),
          );
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
                    if (_preparedUrl != audioUrl ||
                        _position == Duration.zero) {
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
          cardContent = _buildPersonalizedInsightCard(
            card,
            theme,
            pillBg,
            textTheme,
          );
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

  Widget _buildPersonalizedInsightCard(
    InsightCard card,
    _CardColorTheme theme,
    Color pillBg,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                Icon(
                  Icons.format_quote,
                  size: 18,
                  color: theme.text.withValues(alpha: 0.5),
                ),
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

  Widget _buildSurahGuidanceCard(
    InsightCard card,
    _CardColorTheme theme,
    Color pillBg,
    TextTheme textTheme,
  ) {
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
        if (card.transliteration != null &&
            card.transliteration!.isNotEmpty) ...[
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

  Widget _buildStoryTaskCard(
    InsightCard card,
    _CardColorTheme theme,
    Color pillBg,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (card.story != null && card.story!.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
          if (card.storyReference != null &&
              card.storyReference!.isNotEmpty) ...[
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
                  child: Icon(
                    Icons.check_circle_outline,
                    color: theme.text,
                    size: 20,
                  ),
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
                      if (card.taskDescription != null &&
                          card.taskDescription!.isNotEmpty) ...[
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

  // TODO(RELEASE): remove debug day-override (counter, tap hook, sheet).
  int _debugTapCount = 0;

  void _onLogoTap() {
    if (!kDebugMode) return;
    _debugTapCount++;
    if (_debugTapCount >= 5) {
      _debugTapCount = 0;
      _showDebugDaySheet();
    }
  }

  Future<void> _showDebugDaySheet() async {
    final controller = TextEditingController(
      text: InsightService.debugDayOverride ?? '',
    );
    final applied = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Debug: mock day'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Effective day: ${InsightService.effectiveDay}\n'
              'Deck: ${_deckId ?? 'none'} · queue: $_queueDepth',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'YYYY-MM-DD (empty = device date)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (applied == null || !mounted) return;
    InsightService.setDebugDayOverride(applied.isEmpty ? null : applied);
    // Reload through the normal path (cache paint + background revalidate).
    _initData();
  }

  Future<bool> _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) async {
    HapticFeedback.lightImpact();
    if (currentIndex != null && _insightCards.isNotEmpty) {
      _topIndex = currentIndex % _insightCards.length;
    }
    // If the Ayah card was swiped, optionally fetch a new one
    // We are implementing looping, so they can keep swiping it.
    // Let's just allow it completely
    return true;
  }

  void _onDeviceScreenshot() {
    if (!mounted) return;
    // Let the OS finish writing its screenshot first.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      unawaited(_offerShare('screenshot'));
    });
  }

  /// Render the visible page (brand background + top bar + cards) to a temp
  /// PNG for story sharing, at device resolution so stories stay crisp.
  Future<String?> _captureTopCard() async {
    try {
      final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 3.0;
      final bytes = await _shotController.capture(
        pixelRatio: dpr.clamp(1.0, 3.0).toDouble(),
      );
      if (bytes == null) return null;
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/insight_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Offer the story share sheet once per card per source. Returns true when
  /// the sheet was shown (callers use it to suppress competing sheets).
  Future<bool> _offerShare(String source) async {
    if (!mounted || _insightCards.isEmpty || _isLoading) return false;
    // OS detection is app-wide (and the MediaStore observer on Android <14
    // even fires for other apps' images), so only react while the app is
    // foregrounded, this tab is the visible page, and nothing is on top.
    if (!_isAppResumed || !_isPageVisible()) return false;
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;
    final topId = _insightCards[_topIndex % _insightCards.length].id ?? '';
    final key = '$source:$topId:${_deckId ?? ''}';
    if (_shareOfferedCardKeys.contains(key)) return false;
    final path = await _captureTopCard();
    if (!mounted || path == null) return false;
    // Consume the key only when the sheet will actually show, so a
    // suppressed attempt (other tab, failed capture) doesn't burn it.
    _shareOfferedCardKeys.add(key);
    await showShareInsightSheet(context, imagePath: path, source: source);
    return true;
  }

  /// All tabs share one route, so ModalRoute.isCurrent can't tell them
  /// apart. Hidden PageView tabs sit one full screen width to the side —
  /// check this page's render box is (mostly) on screen.
  bool _isPageVisible() {
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return false;
    final screen = MediaQuery.sizeOf(context);
    final origin = ro.localToGlobal(Offset.zero);
    return origin.dx > -ro.size.width * 0.5 &&
        origin.dx < screen.width - ro.size.width * 0.5 &&
        origin.dy > -ro.size.height * 0.5 &&
        origin.dy < screen.height - ro.size.height * 0.5;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin.
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
      // Full-bleed capture: the brand background + "meowmin" top bar + cards
      // all live inside the Screenshot, so shared story images carry the app
      // name (free marketing when users post them).
      body: Screenshot(
        controller: _shotController,
        child: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                // ── Top Bar: Avatar · Logo · Favorites ──────────────────────────
                SizedBox(
                  height: 128,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
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
                                      child: DeferredLottie(
                                        asset:
                                            'assets/photos/elements/music_fly.json',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: cs.primaryContainer,
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/photos/mascot/face.webp',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.auto_awesome_rounded,
                                      color: cs.onSurface,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: GestureDetector(
                              onTap: _onLogoTap,
                              child:
                                  Image.asset(
                                    'assets/photos/elements/meowmin.webp',
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
                              MaterialPageRoute(
                                builder: (_) => const FavoritesPage(),
                              ),
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
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: LayoutBuilder(
                            builder: (context, constraints) => SizedBox(
                              width: MediaQuery.of(context).size.width * 0.9,
                              // +40% card height (620 → 868), clamped to what
                              // fits so small screens never overflow. Card text
                              // scrolls internally (ReflectCard), so taller type
                              // can't clip.
                              height: math.min(868.0, constraints.maxHeight),
                              child: MediaQuery(
                                data: MediaQuery.of(context).copyWith(
                                  textScaler: const TextScaler.linear(0.98),
                                ),
                                // While loading there is no skeleton: the real deck
                                // shows frozen (non-interactive) until insights
                                // load. Empty + loading renders blank, then the
                                // deck pops in once cached.
                                child: IgnorePointer(
                                  ignoring: _isLoading,
                                  child: _deck.isNotEmpty
                                      ? CardSwiper(
                                          controller: _swiperController,
                                          cardsCount: _deck.length,
                                          numberOfCardsDisplayed:
                                              _deck.length >= 3
                                              ? 3
                                              : _deck.length,
                                          onSwipe: _onSwipe,
                                          isLoop: true,
                                          cardBuilder:
                                              (
                                                context,
                                                index,
                                                percentThresholdX,
                                                percentThresholdY,
                                              ) {
                                                final cardId =
                                                    _insightCards[index].id ??
                                                    'idx_$index';
                                                final revealed = _revealedCards
                                                    .contains(cardId);
                                                Widget card = _deck[index];

                                                if (!revealed &&
                                                    _revealedLoaded &&
                                                    _scratchCardImages
                                                        .isNotEmpty) {
                                                  // Rotation queue: no repeats until every
                                                  // unlocked face has been shown.
                                                  final scratchImage =
                                                      _scratchFaceFor(index) ??
                                                      _scratchCardImages[index %
                                                          _scratchCardImages
                                                              .length];
                                                  card = ClipRRect(
                                                    // Keyed by card + face so the swiper
                                                    // never reuses a stale face image
                                                    // (the 3rd-card flash bug).
                                                    key: ValueKey(
                                                      'scratch_${cardId}_$scratchImage',
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          32,
                                                        ),
                                                    child: Stack(
                                                      children: [
                                                        Scratcher(
                                                          brushSize: 30,
                                                          threshold: 35,
                                                          image:
                                                              scratchImage
                                                                  .startsWith(
                                                                    'http',
                                                                  )
                                                              ? Image.network(
                                                                  scratchImage,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  errorBuilder:
                                                                      (
                                                                        _,
                                                                        __,
                                                                        ___,
                                                                      ) =>
                                                                          const SizedBox.shrink(),
                                                                )
                                                              : Image.asset(
                                                                  scratchImage,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                ),
                                                          onScratchStart: () {
                                                            HapticFeedback.mediumImpact();
                                                            _purrPlayer
                                                                .setReleaseMode(
                                                                  ReleaseMode
                                                                      .loop,
                                                                );
                                                            _purrPlayer.play(
                                                              AssetSource(
                                                                'tunes/sfx/cat_purr.mp3',
                                                              ),
                                                            );
                                                          },
                                                          onScratchEnd: () {
                                                            _purrPlayer.stop();
                                                          },
                                                          onThreshold: () {
                                                            _purrPlayer.stop();
                                                            final id =
                                                                _insightCards[index]
                                                                    .id ??
                                                                'idx_$index';
                                                            setState(
                                                              () =>
                                                                  _revealedCards
                                                                      .add(id),
                                                            );
                                                            _saveRevealedCards();
                                                            HapticFeedback.heavyImpact();
                                                            _triggerConfetti();
                                                            _rewardPlayer.play(
                                                              AssetSource(
                                                                'tunes/positive_tone_a6b6.wav',
                                                              ),
                                                            );
                                                            ShopService.awardStars(
                                                              'quran_read',
                                                            );
                                                            if (_revealedCards
                                                                    .length ==
                                                                1) {
                                                              AnalyticsService
                                                                  .instance
                                                                  .logFirstTrueAction(
                                                                    which:
                                                                        'scratch',
                                                                    action:
                                                                        'reveal',
                                                                  );
                                                            }
                                                            // Full reveal: ack server-side (idempotent) so
                                                            // tomorrow's serve advances. No same-day swap:
                                                            // 1 deck/day, revealed cards stay readable.
                                                            if (isDeckFullyRevealed(
                                                              _insightCards
                                                                  .map(
                                                                    (c) =>
                                                                        c.id ??
                                                                        '',
                                                                  )
                                                                  .toSet(),
                                                              _revealedCards,
                                                            )) {
                                                              final ids = _insightCards
                                                                  .map(
                                                                    (c) =>
                                                                        c.id ??
                                                                        '',
                                                                  )
                                                                  .where(
                                                                    (id) => id
                                                                        .isNotEmpty,
                                                                  )
                                                                  .toList();
                                                              InsightService.ackDeckRevealed(
                                                                _deckId,
                                                                ids,
                                                              );
                                                              // Free users: paywall after the last
                                                              // scratch-card reveal of the deck.
                                                              if (mounted) {
                                                                MomentPaywallService.maybeShow(
                                                                  context,
                                                                  moment: 'deck_revealed',
                                                                );
                                                              }
                                                            }
                                                          },
                                                          child: card,
                                                        ),
                                                        IgnorePointer(
                                                          child: Shimmer.fromColors(
                                                            baseColor: Colors
                                                                .transparent,
                                                            highlightColor:
                                                                Colors.white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.25,
                                                                    ),
                                                            period:
                                                                const Duration(
                                                                  milliseconds:
                                                                      2000,
                                                                ),
                                                            child: Container(
                                                              color:
                                                                  Colors.black,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                } else {
                                                  card = ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          32,
                                                        ),
                                                    child: GestureDetector(
                                                      onDoubleTapDown: (details) async {
                                                        _showHeart();
                                                        _favoriteCurrentInsight(
                                                          index,
                                                        );
                                                        HapticFeedback.mediumImpact();
                                                        if (_insightCards
                                                            .isNotEmpty) {
                                                          _topIndex =
                                                              index %
                                                              _insightCards
                                                                  .length;
                                                        }
                                                        // A like doubles as a share trigger;
                                                        // skip the delight sheet when the share
                                                        // sheet is offered so sheets never stack.
                                                        final offered =
                                                            await _offerShare(
                                                              'like',
                                                            );
                                                        if (!offered) {
                                                          _scheduleDelightSheet();
                                                        }
                                                      },
                                                      child: Stack(
                                                        children: [
                                                          card,
                                                          for (final heart
                                                              in _hearts)
                                                            IgnorePointer(
                                                              child:
                                                                  _HeartWidget(
                                                                    heart:
                                                                        heart,
                                                                  ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }

                                                return card;
                                              },
                                        )
                                      : _isLoading
                                      ? const SizedBox.shrink()
                                      : const MascotEmptyState(
                                          message:
                                              'Start journaling to unlock\nyour daily insight cards.',
                                          actionLabel: 'Write a journal entry',
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
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
    _scaleAnim = Tween<double>(
      begin: 0.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
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
