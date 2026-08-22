import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../firebase_options.dart';
import 'notification_service.dart';
import 'journal_service.dart';
import 'journal_sync_service.dart';
import 'audio_service.dart';
import 'sfx_service.dart';
import 'user_service.dart';
import 'streak_service.dart';
import 'auth_service.dart';
import 'crypto_service.dart';
import 'journal_remote_storage.dart';
import 'analytics_service.dart';
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
  static bool _firebaseInitialized = false;

  /// Fast path: only init Firebase so the splash screen can render immediately.
  /// Called from main() before runApp().
  static Future<void> initFirebaseOnly() async {
    if (_firebaseInitialized) return;
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    _firebaseInitialized = true;
  }

  /// Initialize core services: CryptoService, anonymous auth, RevenueCat.
  /// Called from the splash screen after it renders.
  /// Idempotent — safe to call multiple times.
  static Future<void> run() async {
    if (_coreInitialized) return;

    await initFirebaseOnly();

    await CryptoService.init();
    PwaInstallService.init();

    // Wait for Firebase Auth to restore session from platform storage
    // (localStorage on web, Keychain on iOS, Keystore on Android).
    // If no user after 1 second, fall back to anonymous.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Give Firebase Auth a moment to restore from local storage
      final restored = await _waitForAuth(timeout: const Duration(seconds: 1));
      if (restored == null) {
        try {
          final guest = await FirebaseAuth.instance.signInAnonymously();
          if (guest.user != null) {
            UserService.syncUser(guest.user!);
          }
        } catch (e) {
          debugPrint('[AppBootstrap] Anonymous sign-in failed: $e');
        }
      } else {
        debugPrint('[AppBootstrap] Restored session for ${restored.email ?? restored.uid}');
        UserService.syncUser(restored);
      }
    }

    // Complete a Google sign-in that went through the redirect flow
    // (iOS Safari / blocked popup). Safe no-op on native and when no
    // redirect is pending. Must run after Firebase Auth is restored above.
    await AuthService.completeRedirectSignIn();

    // Parallelize independent init: crypto key fetch + RevenueCat init.
    // These have no dependency on each other.
    final cryptoKeyFuture = CryptoService.fetchAndStoreKey();
    final revenuecatFuture = RevenueCatService.instance.initialize();
    await Future.wait([cryptoKeyFuture, revenuecatFuture]);

    // Defer encrypted cache warming — runs later via initBackgroundServices().
    // This avoids blocking the splash → homescreen transition.

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await RevenueCatService.instance.identify(user.uid);
    }

    _coreInitialized = true;

    // Log app open event for analytics
    try {
      AnalyticsService.instance.logAppOpen();
    } catch (_) {}
  }

  /// Wait for Firebase Auth to emit a non-null user (session restored from
  /// local storage) or timeout.
  static Future<User?> _waitForAuth({Duration timeout = const Duration(seconds: 2)}) async {
    final completer = Completer<User?>();

    // Check if already signed in
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      return current;
    }

    final sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!completer.isCompleted) completer.complete(user);
    });

    // Wait for auth state change or timeout
    final result = await completer.future.timeout(timeout, onTimeout: () => null);
    await sub.cancel();
    return result;
  }

  /// Initialize background services: notifications, Workmanager, music, SFX,
  /// journal auto-sync, and streak tracking.
  /// Called after the splash → homescreen transition completes.
  static Future<void> initBackgroundServices() async {
    await run();

    // Pull a session-restored (returning) user's cloud journals into local
    // storage so pre-existing entries appear. Explicit Google sign-in already
    // does this via _completeGoogleSignIn; this covers app-launch restore
    // (new device, reinstall, or cleared local cache) where no sign-in event
    // fires. Fire-and-forget: the home screen is already visible, and
    // notifyJournalsChanged() refreshes it once the pull lands.
    final restoredUser = FirebaseAuth.instance.currentUser;
    if (restoredUser != null && !restoredUser.isAnonymous) {
      JournalRemoteStorage.pullAllJournalsToLocal()
          .then((_) => JournalService.notifyJournalsChanged())
          .catchError((e) => debugPrint('[AppBootstrap] journal pull failed: $e'));
    }

    // Warm encrypted cache now that crypto key is available.
    await JournalService.warmEncryptedCache();

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
