import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/analytics_service.dart';
import 'services/app_bootstrap.dart';
import 'core/app_navigator.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('Null check operator used on a null value') ||
        msg.contains('RenderBox was not laid out') ||
        msg.contains('does not have any constraints before it has been laid out')) {
      return;
    }
    FlutterError.dumpErrorToConsole(details);
  };

  await AppBootstrap.run();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
      title: 'Meowmin AI Diary',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(scheme),
      themeMode: ThemeMode.dark,
      navigatorKey: appNavigatorKey,
      navigatorObservers: [AnalyticsService.instance.observer],
      home: const SplashScreen(),
    );
  }
}
