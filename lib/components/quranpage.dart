import 'dart:convert';
import 'package:expressive_loading_indicator/expressive_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wavy_play_button.dart';
import 'package:material_new_shapes/material_new_shapes.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  bool _refreshing = false;
  bool _playing = false;
  String? _error;
  int clicked = 0;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  String arabic = '';
  String transliteration = '';
  String english = '';
  String surah = '';
  int ayahNumber = 0;
  int globalAyahNumber = 0;
  String audioUrl = '';

  final AudioPlayer _player = AudioPlayer();
  String _preparedUrl = '';

  final ScrollController _scrollController = ScrollController();
  double _pullProgress = 0;
  bool _armedRefresh = false;
  bool _thresholdReached = false;
  bool _isReleasingPull = false;

  @override
  void initState() {
    super.initState();
    _player.stop();
    _player.setPlayerMode(PlayerMode.mediaPlayer);
    _fetchAyah();

    _scrollController.addListener(_handlePullRefresh);

    _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playing = state == PlayerState.playing;
        });
      }
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

  void _handlePullRefresh() {
    final offset = _scrollController.offset;

    if (offset < 0) {
      final progress = (-offset / 120).clamp(0.0, 1.25).toDouble();
      final reachedThresholdNow = progress >= 1.0;

      if (reachedThresholdNow && !_thresholdReached) {
        HapticFeedback.selectionClick();
      }

      if (mounted) {
        if ((progress - _pullProgress).abs() > 0.02) {
          setState(() {
            _pullProgress = progress;
          });
        }
        setState(() {
          // _pullProgress = progress;
          _thresholdReached = reachedThresholdNow;
          _isReleasingPull = false;
        });
      }
      return;
    }

    if (_pullProgress > 0 && mounted) {
      setState(() {
        _pullProgress = 0;
        _isReleasingPull = true;
      });
    }

    if (_thresholdReached && !_armedRefresh) {
      _armedRefresh = true;
      HapticFeedback.mediumImpact();
      _fetchAyah(forceRefresh: true).whenComplete(() {
        _armedRefresh = false;
      });
    }

    _thresholdReached = false;
  }

  Future<void> _fetchAyah({bool forceRefresh = false}) async {
    setState(() {
      _refreshing = true;
      _error = null;
      _playing = false;
      _position = Duration.zero;
      _duration = Duration.zero;
      audioUrl = '';
      _preparedUrl = '';
    });
    await _player.stop();

    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final cachedDate = prefs.getString('ayah_date');

      if (!forceRefresh && cachedDate == today) {
        final cachedData = prefs.getString('ayah_data');
        if (cachedData != null) {
          final data = jsonDecode(cachedData);
          setState(() {
            arabic = data['arabic'];
            transliteration = data['transliteration'];
            english = data['english'];
            surah = data['surah'];
            ayahNumber = data['ayahNumber'];
            globalAyahNumber = data['globalAyahNumber'];
            audioUrl = data['audioUrl'];
            _refreshing = false;
          });
          HapticFeedback.mediumImpact();
          try {
            await _player.setSource(UrlSource(audioUrl));
            _preparedUrl = audioUrl;
          } catch (_) {}
          return;
        }
      }

      final textRes = await http.get(
        Uri.parse(
          'https://api.alquran.cloud/v1/ayah/random/editions/'
          'quran-uthmani,en.transliteration,en.sahih',
        ),
      );

      final textData = jsonDecode(textRes.body)['data'];

      final arabicAyah = textData[0];
      final transliterationAyah = textData[1];
      final englishAyah = textData[2];

      globalAyahNumber = arabicAyah['number'];

      final audioRes = await http.get(
        Uri.parse(
          'https://api.alquran.cloud/v1/ayah/$globalAyahNumber/ar.alafasy',
        ),
      );

      final audioData = jsonDecode(audioRes.body)['data'];

      setState(() {
        arabic = arabicAyah['text'];
        transliteration = transliterationAyah['text'];
        english = englishAyah['text'];
        surah = arabicAyah['surah']['englishName'];
        ayahNumber = arabicAyah['numberInSurah'];
        audioUrl = audioData['audio'];
        _refreshing = false;
      });

      HapticFeedback.mediumImpact();

      try {
        await _player.setSource(UrlSource(audioUrl));
        _preparedUrl = audioUrl;
      } catch (_) {}

      final dataToCache = {
        'arabic': arabic,
        'transliteration': transliteration,
        'english': english,
        'surah': surah,
        'ayahNumber': ayahNumber,
        'globalAyahNumber': globalAyahNumber,
        'audioUrl': audioUrl,
      };
      await prefs.setString('ayah_date', today);
      await prefs.setString('ayah_data', jsonEncode(dataToCache));
    } catch (e) {
      setState(() {
        _error = 'Failed to load verse';
        _refreshing = false;
      });
    }
  }

  Future<void> _toggleAudio() async {
    if (audioUrl.isEmpty) return;

    HapticFeedback.mediumImpact();

    if (_playing) {
      await _player.pause();
      return;
    }

    setState(() => clicked += 1);

    try {
      if (_preparedUrl != audioUrl) {
        try {
          await _player.setSource(UrlSource(audioUrl));
        } catch (_) {
          try {
            await _player.setSourceUrl(audioUrl);
          } catch (_) {}
        }
        _preparedUrl = audioUrl;
      }
      await _player.resume();
    } catch (e) {
      try {
        await _player.play(UrlSource(audioUrl));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // centerTitle: true,
        title: Text(
          'Ayaah of the Day',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        // iconTheme: IconThemeData(color: colorScheme.primary),
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 16),
        //     child: AnimatedSwitcher(
        //       duration: const Duration(milliseconds: 300),
        //       child: _refreshing
        //           ? SizedBox(
        //               width: 36,
        //               height: 36,
        //               // child: ExpressiveLoader(),
        //               child: ExpressiveLoadingIndicator( polygons: [
        //         MaterialShapes.softBurst,
        //         MaterialShapes.pill,
        //         MaterialShapes.pentagon,
        //         MaterialShapes.oval,
        //       ],
        //       )
        //             )
        //           : const SizedBox.shrink(),
        //     ),
        //   ),
        // ],
      ),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              /// 👇 EXPRESSIVE REFRESH INDICATOR
              SliverToBoxAdapter(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: _isReleasingPull ? 420 : 90),
                  curve: _isReleasingPull ? Curves.elasticIn : Curves.easeOut,
                  height: _pullProgress == 0 ? 0 : 120 * _pullProgress,
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: _pullProgress.clamp(0.0, 1.0).toDouble(),
                    child: Transform.scale(
                      scale: 0.6 + (_pullProgress * 0.6),
                      child: ExpressiveLoadingIndicator(
                        polygons: [
                          MaterialShapes.softBurst,
                          MaterialShapes.pill,
                          MaterialShapes.pentagon,
                          MaterialShapes.oval,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              /// YOUR PAGE CONTENT
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
                sliver: SliverToBoxAdapter(child: _buildContent()),
              ),
            ],
          ),

          /// Bottom audio button stays pinned
          Padding(
            padding: const EdgeInsets.only(bottom: 100),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: WavyPlayButton(
                isPlaying: _playing,
                progress: _duration.inMilliseconds > 0
                    ? _position.inMilliseconds / _duration.inMilliseconds
                    : 0.0,
                onTap: _toggleAudio,
              ),
            ),
          ),
          // SizedBox(height: 60),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Build the page content as a separate method within the state class
  Widget _buildContent() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 34),
        if (_error != null) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colorScheme.onErrorContainer,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        Text(
          arabic,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 32,
            height: 1.6,
            fontFamily: 'Amiri',
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          transliteration,
          style: textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            height: 1.4,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '\u201c$english\u201d',
          style: textTheme.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.5,
            fontStyle: FontStyle.italic,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '\u2014 $surah : $ayahNumber',
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
