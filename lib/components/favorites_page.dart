import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/favorites_service.dart';
import '../core/app_background.dart';

class _CardColorTheme {
  final Color bg;
  final Color text;
  final Color accent;
  const _CardColorTheme({required this.bg, required this.text, required this.accent});
}

const List<_CardColorTheme> _cardColorSchemes = [
  _CardColorTheme(bg: Color(0xFFD6DF7E), text: Color(0xFF13441A), accent: Color(0xFF187B25)),
  _CardColorTheme(bg: Color(0xFFFAA49A), text: Color(0xFF4E1106), accent: Color(0xFFC4391D)),
  _CardColorTheme(bg: Color(0xFFA0C4FF), text: Color(0xFF00154F), accent: Color(0xFF0052FF)),
  _CardColorTheme(bg: Color(0xFFFFF0B2), text: Color(0xFF4E2E00), accent: Color(0xFFA86200)),
];

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<FavoriteItem> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final faves = await FavoritesService.getFavorites();
    if (mounted) setState(() { _favorites = faves; _loading = false; });
  }

  Future<void> _remove(FavoriteItem item) async {
    final key = FavoritesService.itemKey(item);
    await FavoritesService.removeFavorite(key);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Favorite Insights',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        actions: [
          if (_favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('favorite_insights');
                await _load();
              },
            ),
        ],
      ),
      body: AppBackground(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_border, size: 72, color: cs.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'No favorites yet',
                          style: tt.titleLarge?.copyWith(color: cs.onSurface.withValues(alpha: 0.5)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Double-tap a revealed card in the Quran page to save it here',
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _favorites.length,
                    itemBuilder: (context, index) {
                    final item = _favorites[index];
                    return _buildCard(item, index, tt);
                  },
                ),
      ),
    );
  }

  Widget _buildCard(FavoriteItem item, int index, TextTheme tt) {
    final scheme = _cardColorSchemes[index % _cardColorSchemes.length];
    return Dismissible(
      key: ValueKey(FavoritesService.itemKey(item)),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: scheme.text.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.delete, color: scheme.text),
      ),
      onDismissed: (_) => _remove(item),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: scheme.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.text.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                    Icon(
                      item.type == FavoriteType.insight
                          ? Icons.auto_awesome
                          : Icons.menu_book_rounded,
                      size: 20,
                      color: scheme.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.type == FavoriteType.insight ? 'Insight' : 'Quran Verse',
                      style: tt.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.text,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(item.savedAt),
                      style: tt.labelSmall?.copyWith(color: scheme.text.withValues(alpha: 0.5)),
                    ),
                ],
              ),
              if (item.type == FavoriteType.insight) ...[
                const SizedBox(height: 12),
                if (item.greeting != null)
                  Text(item.greeting!, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.text)),
                const SizedBox(height: 6),
                Text(item.insight ?? '', style: tt.bodyMedium?.copyWith(height: 1.5, color: scheme.text)),
                if (item.quote != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: scheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.quote!,
                          style: tt.bodySmall?.copyWith(fontStyle: FontStyle.italic, height: 1.5, color: scheme.text),
                        ),
                        if (item.reference != null) ...[
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text('— ${item.reference}', style: tt.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: scheme.text)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ] else ...[
                const SizedBox(height: 12),
                Text(item.arabic ?? '', style: TextStyle(fontSize: 22, fontFamily: 'Amiri', height: 1.6, color: scheme.text)),
                const SizedBox(height: 8),
                Text(item.transliteration ?? '', style: tt.bodySmall?.copyWith(color: scheme.text.withValues(alpha: 0.7))),
                const SizedBox(height: 8),
                Text('"${item.english ?? ""}"', style: tt.bodyMedium?.copyWith(fontStyle: FontStyle.italic, height: 1.5, color: scheme.text)),
                const SizedBox(height: 8),
                Text('${item.surah} : ${item.ayahNumber}', style: tt.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: scheme.accent)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}
