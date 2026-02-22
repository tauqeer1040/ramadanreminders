import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  bool _loading = true;
  bool _playing = false;
  String? _error;
  int clicked = 0;

  String arabic = '';
  String transliteration = '';
  String english = '';
  String surah = '';
  int ayahNumber = 0; // number in surah
  int globalAyahNumber = 0; // IMPORTANT
  String audioUrl = '';

  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _player.stop();
    _fetchAyah();

    _player.onPlayerStateChanged.listen((state) {
      setState(() {
        _playing = state == PlayerState.playing;
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _fetchAyah() async {
    HapticFeedback.lightImpact();
    setState(() {
      _loading = true;
      _error = null;
      _playing = false;
      audioUrl = '';
    });

    try {
      // 1️⃣ Fetch Arabic + transliteration + English
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

      globalAyahNumber = arabicAyah['number']; // global ayah index

      // 2️⃣ Fetch MP3 audio separately
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
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load verse';
        _loading = false;
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
      await _player.setSource(UrlSource(audioUrl));
      await _player.resume(); // or await _player.play(); depending on version
    } catch (e) {
      // fallback for older versions:
      try {
        await _player.setSourceUrl(audioUrl);
        await _player.resume();
      } catch (err) {
        // last resort:
        await _player.play(UrlSource(audioUrl));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'An Aayah of Qur’an a day',
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.primary),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              icon: const Icon(Icons.refresh),
              onPressed: _fetchAyah,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
            : _error != null
            ? Center(
                child: Text(
                  _error!,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Arabic
                  Text(
                    arabic,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 28, height: 1.6),
                  ),
                  const SizedBox(height: 16),

                  // Transliteration
                  Text(
                    transliteration,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.4,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // English Translation
                  Text(
                    '“$english”',
                    style: textTheme.bodyLarge?.copyWith(
                      fontSize: 16,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // const SizedBox(height: 16),

                  // Debug (optional – remove later)
                  // if (audioUrl.isNotEmpty)
                  //   Text(
                  //     audioUrl,
                  //     style: TextStyle(
                  //       fontSize: 12,
                  //       color: Colors.grey.shade500,
                  //     ),
                  //   ),
                  //   Text('$_playing'),
                  //   Text('$clicked'),

                  // const SizedBox(height: 16),

                  // Citation
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '— $surah : $ayahNumber',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Audio Controls
                  Center(
                    child: IconButton(
                      iconSize: 56,
                      onPressed: _toggleAudio,
                      icon: Icon(
                        _playing
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
