import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'components/homepage.dart';
import 'components/quranpage.dart';
import 'features/tasbih/tasbih_screen.dart';
import 'screens/onboarding_screen.dart';
import 'components/journal_editor_screen.dart';
import 'components/journal_bottom_sheet.dart';
import 'components/profilepage.dart';
import 'core/app_background.dart';
import 'services/streak_service.dart';
import 'services/audio_service.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/journal_service.dart';
import 'services/user_service.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseUIAuth.configureProviders([
      EmailAuthProvider(),
      GoogleProvider(clientId: AuthService.serverClientId),
    ]);
    
    // Natively initialize Guest Account immediately if completely logged out!
    if (FirebaseAuth.instance.currentUser == null) {
      final guest = await FirebaseAuth.instance.signInAnonymously();
      if (guest.user != null) {
        UserService.syncUser(guest.user!);
      }
    }
  } catch (e) {
    debugPrint("Failed to initialize Firebase: $e");
  }

  NotificationService.init();
  NotificationService.requestPermissions();
  NotificationService.scheduleDailyNotifications();

  JournalService.initAutoSync();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  BackgroundMusicService().init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppTheme.neonPurple,
      brightness: Brightness.dark,
    );

    ThemeData buildTheme(ColorScheme scheme) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme.copyWith(
          primary: AppTheme.neonPurple,
          onSurface: AppTheme.starWhite,
          onSurfaceVariant: AppTheme.ghostSilver,
        ),
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
            GoogleFonts.interTextTheme().apply(
              bodyColor: AppTheme.starWhite,
              displayColor: AppTheme.starWhite,
            ),
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
          title: 'NoorAI',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(scheme),
      themeMode: ThemeMode.dark,
      home: const Material3BottomNav(),
    );
  }
}

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});

//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   int _counter = 0;

//   void _incrementCounter() {
//     setState(() {
//       _counter++;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         title: Text(widget.title),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             const Text('You have pushed the button this many times:'),
//             Text(
//               '$_counter',
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _incrementCounter,
//         tooltip: 'Increment',
//         child: const Icon(Icons.add),
//       ),
//     );
//   }
// }

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
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    StreakService.recordActivity();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/photos/elements/app_bg2.webp'), context);
    });
    final prefs = await SharedPreferences.getInstance();
    final complete = prefs.getBool('onboarding_complete') ?? false;
    if (!complete && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
          fullscreenDialog: true,
        ),
      );
    }
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
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() => _selectedIndex = index);
            },
            children: _pages,
          ),
        ),

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final limit = await JournalService.isGuestLimitReached();
          if (limit && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Free Trial limit reached! Tap your Profile to sign up securely and unlock unlimited journals."),
                duration: Duration(seconds: 4),
              ),
            );
            return;
          }
          if (context.mounted) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => const JournalBottomSheet(),
            );
          }
        },
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        child: const Icon(Icons.edit_rounded),
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
        destinations: _buildNavBarItems(cs),
      ),
    );
  }
}

const List<Widget> _pages = [
  Homepage(),
  QuranPage(),
  TasbihScreen(),
  ProfilePage1(),
];

List<NavigationDestination> _buildNavBarItems(ColorScheme cs) {
  final user = AuthService.currentUser;
  final isGuest = user == null || user.isAnonymous;

  Widget profileIcon(bool selected) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: selected ? cs.secondaryContainer : Colors.transparent,
      child: isGuest
        ? Icon(Icons.person_rounded, size: 18, color: cs.onSurface)
        : (user.photoURL != null && user.photoURL!.isNotEmpty)
            ? ClipOval(
                child: Image.network(
                  user.photoURL!,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, size: 18, color: cs.onSurface),
                ),
              )
            : Icon(Icons.person_rounded, size: 18, color: cs.onSurface),
    );
  }

  return [
    const NavigationDestination(
      icon: Icon(Icons.home_filled),
      selectedIcon: Icon(Icons.home_filled),
      label: "home",
    ),
    const NavigationDestination(
      icon: Icon(Icons.menu_book_rounded),
      selectedIcon: Icon(Icons.menu_book_rounded),
      label: 'Quran',
    ),
    const NavigationDestination(
      icon: Icon(Icons.loop_rounded),
      selectedIcon: Icon(Icons.loop_rounded),
      label: 'Tesbih',
    ),
    NavigationDestination(
      icon: profileIcon(false),
      selectedIcon: profileIcon(true),
      label: 'profile',
    ),
  ];
}


