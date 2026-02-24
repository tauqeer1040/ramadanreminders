import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'components/homepage.dart';
import 'components/profilepage.dart';
import 'components/quranpage.dart';
import 'features/tasbih/tasbih_screen.dart';

void main() {
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Fallback seed color (Deep Teal/Green for a calmer, better contrast Ramadan theme)
    const defaultColor = Color(0xFF006A60);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ColorScheme lightScheme;
        ColorScheme darkScheme;

        if (lightDynamic != null && darkDynamic != null) {
          lightScheme = lightDynamic.harmonized();
          darkScheme = darkDynamic.harmonized();
        } else {
          lightScheme = ColorScheme.fromSeed(
            seedColor: defaultColor,
            brightness: Brightness.light,
          );
          darkScheme = ColorScheme.fromSeed(
            seedColor: defaultColor,
            brightness: Brightness.dark,
          );
        }

        ThemeData buildTheme(ColorScheme scheme) {
          return ThemeData(
            useMaterial3: true,
            colorScheme: scheme,
            scaffoldBackgroundColor: scheme.surface,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
              },
            ),
            textTheme:
                GoogleFonts.interTextTheme(), // Apply modern sans globally
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              elevation: 0,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                elevation: 0,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                elevation: 0,
              ),
            ),
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                elevation: 0,
              ),
            ),
          );
        }

        return MaterialApp(
          title: 'Ramadan Reflections',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(lightScheme),
          darkTheme: buildTheme(darkScheme),
          themeMode: ThemeMode.system,
          home: const Material3BottomNav(),
        );
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

// import 'package:flutter/material.dart';

class Material3BottomNav extends StatefulWidget {
  const Material3BottomNav({super.key});

  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_Material3BottomNavState>();
    state?.navigateToTab(index);
  }

  @override
  State<Material3BottomNav> createState() => _Material3BottomNavState();
}

class _Material3BottomNavState extends State<Material3BottomNav> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void navigateToTab(int index) {
    setState(() => _selectedIndex = index);

    // Jump instantly for tabs that are far away so the user doesn't
    // watch a slow multi-screen scroll-through.
    final distance = (_selectedIndex - (_pageController.page ?? _selectedIndex))
        .abs();
    if (distance > 1.5) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubicEmphasized,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Container(
        decoration: BoxDecoration(
          // Material 3 Expressive background wash using core semantic containers
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primaryContainer.withValues(alpha: 0.3),
              cs.surface,
              cs.secondaryContainer.withValues(alpha: 0.3),
              cs.tertiaryContainer.withValues(alpha: 0.3),
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
        child: PageView(
          controller: _pageController,
          // BouncingScrollPhysics gives a fluid, natural deceleration curve
          // instead of the abrupt clamp on Android's default.
          physics: const BouncingScrollPhysics(parent: PageScrollPhysics()),
          onPageChanged: (index) {
            setState(() => _selectedIndex = index);
          },
          children: _pages,
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGlobalPremiumSheet(context),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        icon: const Icon(Icons.workspace_premium_rounded),
        label: const Text(
          'Premium',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.8),
        indicatorColor: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.8),
        animationDuration: const Duration(milliseconds: 400),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          HapticFeedback.lightImpact();
          navigateToTab(index);
        },
        destinations: _navBarItems,
      ),
    );
  }
}

const List<Widget> _pages = [
  Homepage(),
  TasbihScreen(),
  QuranPage(),
  ProfilePage1(),
];

const _navBarItems = [
  NavigationDestination(
    icon: Icon(Icons.home_filled),
    selectedIcon: Icon(Icons.home_filled),
    label: "home",
  ),
  NavigationDestination(
    icon: Icon(Icons.loop_rounded),
    selectedIcon: Icon(Icons.loop_rounded),
    label: 'Tesbih',
  ),
  NavigationDestination(
    icon: Icon(Icons.menu_book_rounded),
    selectedIcon: Icon(Icons.menu_book_rounded),
    label: 'Quran',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline_rounded),
    selectedIcon: Icon(Icons.person_rounded),
    label: 'Profile',
  ),
];

void _showGlobalPremiumSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // M3: showDragHandle renders the spec-compliant handle and top padding
    showDragHandle: true,
    // M3: useSafeArea ensures the sheet respects system insets
    useSafeArea: true,
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(
              children: [
                // M3 filled icon container — uses secondaryContainer token
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: cs.onSecondaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ramadan Premium',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Unlock the full experience',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Perks list ────────────────────────────────────────────────
            ...([
              (
                Icons.all_inclusive_rounded,
                'Unlimited custom Tasbihayat',
                cs.primaryContainer,
                cs.onPrimaryContainer,
              ),
              (
                Icons.bar_chart_rounded,
                'Daily & weekly dhikr statistics',
                cs.secondaryContainer,
                cs.onSecondaryContainer,
              ),
              (
                Icons.notifications_active_rounded,
                'Smart prayer-time reminders',
                cs.tertiaryContainer,
                cs.onTertiaryContainer,
              ),
              (
                Icons.cloud_sync_rounded,
                'Cross-device sync & backup',
                cs.primaryContainer,
                cs.onPrimaryContainer,
              ),
              (
                Icons.auto_awesome_rounded,
                'Ad-free & distraction-free',
                cs.secondaryContainer,
                cs.onSecondaryContainer,
              ),
            ].map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: p.$3,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(p.$1, size: 20, color: p.$4),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      p.$2,
                      style: tt.bodyLarge?.copyWith(color: cs.onSurface),
                    ),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 20),

            // ── CTA — standard M3 FilledButton ────────────────────────────
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.star_rounded),
              label: const Text('Get Premium'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Soft dismiss ──────────────────────────────────────────────
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Maybe later'),
              ),
            ),
          ],
        ),
      );
    },
  );
}
