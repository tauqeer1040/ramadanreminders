import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/app_bootstrap.dart';
import 'services/crash_reporter.dart';
import 'core/app_navigator.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Prevent GoogleFonts from fetching fonts over the network.
  // Inter is self-hosted via assets/fonts/Inter-latin.woff2 + pubspec.yaml.
  GoogleFonts.config.allowRuntimeFetching = false;

  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('Null check operator used on a null value') ||
        msg.contains('RenderBox was not laid out') ||
        msg.contains('does not have any constraints before it has been laid out')) {
      return;
    }
    FlutterError.dumpErrorToConsole(details);
  };

  // Report uncaught errors (and web JS errors) to Firebase Analytics.
  // Installed after the noise filter above so it can chain to it.
  CrashReporter.init();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Firebase must be initialized before runApp() so that widgets which
  // reference FirebaseAnalytics.instance during build don't crash.
  // Heavy init (auth, RevenueCat, etc.) stays deferred in the splash.
  await AppBootstrap.initFirebaseOnly();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        textTheme: ThemeData().textTheme.apply(
              fontFamily: 'Inter',
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
      title: 'Meowmin',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(scheme),
      themeMode: ThemeMode.dark,
      navigatorKey: appNavigatorKey,
      navigatorObservers: const [],
      home: const SplashScreen(),
    );
  }
}
