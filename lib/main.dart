import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'components/homepage.dart';
import 'components/profilepage.dart';
import 'components/quranpage.dart';
import 'components/tesbihpage.dart';

void main() {
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
            fontFamily: 'Amiri', // Ensure font consistency globally if desired
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
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.linear,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.8),
        indicatorColor: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.8),
        animationDuration: const Duration(seconds: 1),
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
  // Homepage(),
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
