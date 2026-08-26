import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/version_check_service.dart';
import '../services/app_bootstrap.dart';
import '../services/analytics_service.dart';
import '../screens/onboarding_screen.dart';
import '../screens/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  Widget? _targetScreen;
  bool _isTargetReady = false;
  bool _isTimerDone = false;
  bool _splashFadedOut = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 375),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.fastOutSlowIn,
      ),
    );

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _splashFadedOut = true;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/splash/gif.webp'), context);
    });

    _init();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Firebase is initialized in main() before runApp() (see AppBootstrap.initFirebaseOnly).
    // Heavy core services run separately via the unawaited AppBootstrap.run() below.

    // On web, the HTML splash (animated gif) already played during download —
    // skip the min-splash timer and transition the instant MainScreen is ready.
    final timer = kIsWeb
        ? Future.value()
        : Future.delayed(const Duration(milliseconds: 800));

    // Log session start for analytics
    try {
      AnalyticsService.instance.logSessionStart();
    } catch (_) {}

    // Start core init in background — don't block the splash transition.
    // Background services will call run() again (idempotent) to finish any
    // leftover work.
    unawaited(AppBootstrap.run());

    // ── Mandatory: read onboarding status ──
    bool needsOnboarding;
    if (kIsWeb) {
      // On web, read the pre-determined value from index.html's inline script.
      // This avoids the async SharedPreferences plugin bridge entirely.
      try {
        final jsVal = globalContext['splashNeedsOnboarding'];
        needsOnboarding = jsVal == null || (jsVal as JSBoolean).toDart != true;
      } catch (_) {
        needsOnboarding = true;
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      needsOnboarding = !(prefs.getBool('onboarding_complete') ?? false);
    }

    if (needsOnboarding) {
      if (!kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final asked = prefs.getBool('notification_permission_asked') ?? false;
        if (!asked) {
          await prefs.setBool('notification_permission_asked', true);
          NotificationService.requestPermissions();
        }
      }
      await _performScratchMigration();
      await timer;
      if (!mounted) return;
      if (kIsWeb) {
        setState(() {
          _isTimerDone = true;
          _targetScreen = OnboardingScreen(onReady: _onTargetReady);
        });
      } else {
        _navigate(const OnboardingScreen());
      }
    } else {
      // ── Version check (optional, runs in parallel) ──
      VersionCheckService.check().then((result) {
        if (result != null && mounted) {
          if (result.requiresUpdate) {
            VersionCheckService.showUpdateDialog(context, result, force: true);
          } else if (result.hasUpdate) {
            VersionCheckService.showUpdateDialog(context, result, force: false);
          }
        }
      });

      if (!mounted) return;
      setState(() {
        _targetScreen = MainScreen(onReady: _onTargetReady);
      });

      await timer;
      if (mounted) {
        setState(() {
          _isTimerDone = true;
          _checkTransition();
        });
      }
    }
  }

  void _onTargetReady() {
    if (mounted) {
      setState(() {
        _isTargetReady = true;
        _checkTransition();
      });
    }
  }

  void _checkTransition() {
    if (_isTimerDone && _isTargetReady) {
      if (kIsWeb) {
        // On web, the HTML splash covers the screen until this moment. Remove
        // it now that the target screen has painted — reveals it directly.
        _removeWebSplash();
        Future.delayed(const Duration(milliseconds: 375), () {
          _initBackgroundServices();
        });
      } else {
        _fadeController.forward();
        // Delay services init until transition is 100% complete
        Future.delayed(const Duration(milliseconds: 375), () {
          _initBackgroundServices();
        });
      }
    }
  }

  void _removeWebSplash() {
    // Removes the HTML splash via the global function defined in index.html.
    // If the bridge fails, the 8s failsafe in index.html still clears it.
    try {
      globalContext.callMethod('removeSplashFromWeb'.toJS);
    } catch (_) {}
  }

  Future<void> _initBackgroundServices() async {
    await AppBootstrap.initBackgroundServices();
  }

  void _navigate(Widget screen) {
    final route = PageRouteBuilder(
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: (_, animation, __, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.fastOutSlowIn,
        );
        return FadeTransition(opacity: curvedAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 375),
    );
    Navigator.of(context).pushAndRemoveUntil(route, (route) => false);
  }

  Future<void> _performScratchMigration() async {
    final prefs = await SharedPreferences.getInstance();
    final migrated = prefs.getBool('scratch_migrated') ?? false;
    if (migrated) return;
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
    }
    await prefs.setBool('scratch_migrated', true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_targetScreen != null) ...[
            _targetScreen!,
          ],
          // On web the HTML splash covers the screen — don't double-render the gif.
          if (!kIsWeb && !_splashFadedOut) ...[
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Image.asset(
                    'assets/splash/gif.webp',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
