import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'components/homepage.dart';
import 'components/shop_screen.dart';
import 'components/quranpage.dart';
// import 'features/tasbih/tasbih_screen.dart';
import 'screens/onboarding_screen.dart';
import 'components/profilepage.dart';
import 'core/app_background.dart';
import 'services/streak_service.dart';
import 'services/audio_service.dart';
import 'services/trial_service.dart';
import 'services/sfx_service.dart';
import 'services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/journal_service.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/auth_debug_service.dart';
import 'theme/app_theme.dart';
import 'screens/paywall_gate_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
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
  NotificationService.scheduleDailyNotifications();

  JournalService.initAutoSync();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  
  await BackgroundMusicService().init();
  await SfxService().init();

  try {
    final swOptions = SuperwallOptions()
      ..logging.level = LogLevel.debug;
    Superwall.configure('pk_H_7a9WkW5nHJqKZPKsub1', options: swOptions);
  } catch (e) {
    debugPrint("Superwall configure error: $e");
  }
  
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
          title: 'Meowmin Ai Diary',
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

class _Material3BottomNavState extends State<Material3BottomNav> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  int _shopRefresh = 0;
  final _homepageKey = GlobalKey<HomepageState>();
  late final PageController _pageController;
  StreamSubscription? _authSubscription;
  bool _isSubscribed = false;
  DateTime? _sessionStart;
  Timer? _sessionTimer;

  List<Widget> get _pages => [
    Homepage(key: _homepageKey),
    QuranPage(),
    ShopScreen(key: ValueKey('shop_$_shopRefresh')),
    ProfilePage1(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _selectedIndex);
    _authSubscription = AuthService.userChanges.listen((user) {
      if (mounted) setState(() {});
      AuthDebugService().logAuthStateChange({
        'uid': user?.uid ?? 'null',
        'isAnonymous': '${user?.isAnonymous}',
        'email': user?.email ?? 'none',
        'providerCount': '${user?.providerData.length ?? 0}',
      });
    });
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    await TrialService.initialize();
    await TrialService.initializeGrace();
    StreakService.recordActivity();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/photos/elements/app_bg2.webp'), context);
    });
    final prefs = await SharedPreferences.getInstance();
    final complete = prefs.getBool('onboarding_complete') ?? false;

    // First-ever launch: request notification permission immediately
    if (!complete) {
      final asked = prefs.getBool('notification_permission_asked') ?? false;
      if (!asked) {
        await prefs.setBool('notification_permission_asked', true);
        NotificationService.requestPermissions();
      }
    }

    // One-time migration for existing users: ensure 3 scratch cards unlocked
    if (complete) {
      final migrated = prefs.getBool('scratch_migrated') ?? false;
      if (!migrated) {
        final raw = prefs.getString('shop_unlocked');
        final unlocked = raw != null ? (jsonDecode(raw) as List).cast<String>().toSet() : <String>{};
        final scratchCount = unlocked.where((id) {
          final n = int.tryParse(id.split('_').last) ?? 0;
          return n >= 13 && n <= 21;
        }).length;
        if (scratchCount < 3) {
          for (int i = 13; i <= 15; i++) {
            final id = 'shop_$i';
            if (!unlocked.contains(id)) {
              unlocked.add(id);
            }
          }
          await prefs.setString('shop_unlocked', jsonEncode(unlocked.toList()));
          setState(() => _shopRefresh++);
        }
        await prefs.setBool('scratch_migrated', true);
      }
    }

    if (!complete && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
          fullscreenDialog: true,
        ),
      );
      setState(() => _shopRefresh++);
      await _homepageKey.currentState?.loadStars();
    }

    // Subscription gate check (always, after onboarding or on app start)
    if (mounted) {
      await _checkSubscriptionStatus();
      if (!_isSubscribed) {
        await _showPaywallGate();
      }
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final status = await Superwall.shared.getSubscriptionStatus();
      if (mounted) {
        _isSubscribed = status.isActive;
      }
    } catch (_) {
      // Silently fail — treat as not subscribed
      _isSubscribed = false;
    }
  }

  Future<void> _showPaywallGate() async {
    // Deduct 1 minute for this launch
    final remaining = await TrialService.deductLaunchCost();
    final hasGrace = remaining > 0;
    _sessionTimer?.cancel();

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaywallGateScreen(
          isDismissable: hasGrace,
          onSubscribe: () {
            _isSubscribed = true;
            _sessionTimer?.cancel();
            Navigator.of(context).pop();
          },
          onDismiss: () {
            Navigator.of(context).pop();
            _startSessionTracking();
          },
        ),
      ),
    );
  }

  void _startSessionTracking() {
    _sessionStart = DateTime.now();
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!mounted) {
        _sessionTimer?.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_sessionStart!).inMilliseconds;
      final remaining = await TrialService.getRemainingMs();
      if (remaining <= 0 || elapsed >= remaining) {
        // Consume the elapsed time
        await TrialService.consumeSessionMs(elapsed);
        _sessionTimer?.cancel();
        if (mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => PaywallGateScreen(
                isDismissable: false,
                onSubscribe: () {
                  _isSubscribed = true;
                  _sessionTimer?.cancel();
                  Navigator.of(context).pop();
                },
                onDismiss: () {},
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> _checkGate() async {
    if (_isSubscribed) return;
    await _checkSubscriptionStatus();
    if (_isSubscribed) return;
    final remaining = await TrialService.getRemainingMs();
    if (remaining <= 0) {
      if (mounted) {
        _sessionTimer?.cancel();
        await Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PaywallGateScreen(
              isDismissable: false,
              onSubscribe: () {
                _isSubscribed = true;
                _sessionTimer?.cancel();
                Navigator.of(context).pop();
              },
              onDismiss: () {},
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _pageController.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkGate();
    }
  }

  void navigateToTab(int index) {
    final clamped = index.clamp(0, _pages.length - 1);
    setState(() => _selectedIndex = clamped);

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
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


      bottomNavigationBar: NavigationBar(
        backgroundColor: Theme.of(
          context,
        ).colorScheme.surface.withValues(alpha: 0.8),
        indicatorColor: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.8),
        animationDuration: const Duration(milliseconds: 400),
        selectedIndex: _selectedIndex.clamp(0, _buildNavBarItems(cs).length - 1),
        onDestinationSelected: (index) {
          HapticFeedback.lightImpact();
          navigateToTab(index);
        },
        destinations: _buildNavBarItems(cs),
      ),
    ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit Meowmin Ai Diary?'),
        content: const Text('Are you sure you want to exit the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SystemNavigator.pop();
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }
}

class _ProfileTabIcon extends StatefulWidget {
  final bool selected;
  final ColorScheme cs;

  const _ProfileTabIcon({required this.selected, required this.cs});

  @override
  State<_ProfileTabIcon> createState() => _ProfileTabIconState();
}

class _ProfileTabIconState extends State<_ProfileTabIcon> {
  User? _user;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _user = AuthService.currentUser;
    _sub = AuthService.userChanges.listen((u) {
      if (mounted) setState(() => _user = u);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = AuthService.getPhotoUrl(_user);

    if (photoUrl != null && photoUrl.isNotEmpty) {
      final size = widget.selected ? 28.0 : 24.0;
      final borderWidth = widget.selected ? 2.0 : 1.0;
      final borderColor = widget.selected ? AppTheme.neonPurple : AppTheme.ghostSilver;
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: ClipOval(
          child: Image.network(photoUrl, fit: BoxFit.cover),
        ),
      );
    }

    if (widget.selected) {
      return const Icon(Icons.person_rounded, color: AppTheme.neonPurple);
    }
    return const Icon(Icons.person_outline_rounded, color: AppTheme.ghostSilver);
  }
}

List<NavigationDestination> _buildNavBarItems(ColorScheme cs) {
  return [
    const NavigationDestination(
      icon: Icon(Icons.home_outlined, weight: 200),
      selectedIcon: Icon(Icons.home_outlined, weight: 200),
      label: "home",
    ),
    NavigationDestination(
      icon: ImageIcon(AssetImage('assets/photos/elements/icons8-cards-64.png')),
      selectedIcon: ImageIcon(AssetImage('assets/photos/elements/icons8-cards-64.png')),
      label: 'Insights',
    ),
    const NavigationDestination(
      icon: Icon(Icons.store_outlined, weight: 200),
      selectedIcon: Icon(Icons.store_outlined, weight: 200),
      label: "shop",
    ),
    NavigationDestination(
      icon: _ProfileTabIcon(selected: false, cs: cs),
      selectedIcon: _ProfileTabIcon(selected: true, cs: cs),
      label: 'profile',
    ),
  ];
}


