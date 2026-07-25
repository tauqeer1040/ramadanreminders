import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/journal_service.dart';
import 'services/audio_service.dart';
import 'services/sfx_service.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'services/analytics_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'rescheduleNotifications') {
      final username = inputData?['username'] as String? ?? 'you';
      await NotificationService.scheduleDailyNotifications(username: username);
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Suppress noisy Android logcat lines from Flutter console output.
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('Null check operator used on a null value') ||
        msg.contains('RenderBox was not laid out') ||
        msg.contains('does not have any constraints before it has been laid out')) {
      return;
    }
    FlutterError.dumpErrorToConsole(details);
  };

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Failed to initialize Firebase: $e");
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

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
      navigatorObservers: [AnalyticsService.instance.observer],
      home: const SplashScreen(),
    );
  }
}
