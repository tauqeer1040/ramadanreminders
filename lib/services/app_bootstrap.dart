import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../firebase_options.dart';
import 'notification_service.dart';
import 'journal_sync_service.dart';
import 'audio_service.dart';
import 'sfx_service.dart';
import 'user_service.dart';
import 'streak_service.dart';
import 'crypto_service.dart';
import 'revenuecat_service.dart';
import 'pwa_install_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'rescheduleNotifications') {
      final username = inputData?['username'] as String? ?? 'you';
      await NotificationService.scheduleDailyNotifications(username: username);
    }
    return Future.value(true);
  });
}

class AppBootstrap {
  static bool _coreInitialized = false;

  /// Initialize core services: Firebase, CryptoService, anonymous auth.
  /// Idempotent — safe to call multiple times.
  static Future<void> run() async {
    if (_coreInitialized) return;

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    await CryptoService.init();
    PwaInstallService.init();

    if (FirebaseAuth.instance.currentUser == null) {
      try {
        final guest = await FirebaseAuth.instance.signInAnonymously();
        if (guest.user != null) {
          UserService.syncUser(guest.user!);
        }
      } catch (e) {
        debugPrint('[AppBootstrap] Anonymous sign-in failed: $e');
      }
    }

    await CryptoService.fetchAndStoreKey();

    await RevenueCatService.instance.initialize();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await RevenueCatService.instance.identify(user.uid);
    }

    _coreInitialized = true;
  }

  /// Initialize background services: notifications, Workmanager, music, SFX,
  /// journal auto-sync, and streak tracking.
  static Future<void> initBackgroundServices() async {
    await run();

    if (!kIsWeb) {
      // Local notifications and Workmanager are mobile-only plugins.
      NotificationService.init();
      await Workmanager().initialize(callbackDispatcher);

      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('onboarding_displayName') ??
          FirebaseAuth.instance.currentUser?.displayName ?? 'you';

      await Workmanager().registerPeriodicTask(
        'notification-rescheduler',
        'rescheduleNotifications',
        frequency: const Duration(hours: 12),
        constraints: Constraints(networkType: NetworkType.notRequired),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        inputData: {'username': username},
      );
      await NotificationService.scheduleDailyNotifications(username: username);
    }

    JournalSyncService.initAutoSync();
    await BackgroundMusicService().init();
    await SfxService().init();
    StreakService.recordActivity();
  }
}
