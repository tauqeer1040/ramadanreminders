import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'user_service.dart';
import 'auth_debug_service.dart';
import 'analytics_service.dart';
import 'browser_detector.dart';
import 'crypto_service.dart';
import 'journal_remote_storage.dart';
import 'journal_service.dart';
import 'revenuecat_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Get current user stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static Stream<User?> get userChanges => _auth.userChanges();
  static User? get currentUser => _auth.currentUser;

  static String? getPhotoUrl(User? user) {
    if (user == null || user.isAnonymous) return null;
    for (final p in user.providerData) {
      if (p.providerId == 'google.com' && p.photoURL != null) {
        return p.photoURL;
      }
    }
    return user.photoURL;
  }

  /// Sign in with Google, linking to anonymous account if present
  static Future<UserCredential?> signInWithGoogle() async {
    final debug = AuthDebugService();

    try {
      final currentUser = _auth.currentUser;
      debug.logEvent('STATE', 'Current auth user',
        details: {
          'uid': currentUser?.uid ?? 'null',
          'isAnonymous': '${currentUser?.isAnonymous}',
          'email': currentUser?.email ?? 'none',
          'providerCount': '${currentUser?.providerData.length ?? 0}',
          'platform': kIsWeb ? 'web' : 'native',
        },
      );

      // ── Web: Firebase Auth's signInWithPopup, with a redirect fallback for
      // iOS Safari (ITP frequently breaks popup auth) and blocked popups. ──
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');

        // iOS Safari blocks popup-based auth — go straight to the redirect
        // flow, which completes in completeRedirectSignIn() after the page
        // reloads.
        if (BrowserDetector.info.isIOSafari) {
          debug.logEvent('WEB', 'Using Firebase signInWithRedirect (iOS Safari)');
          await _auth.signInWithRedirect(provider);
          return null;
        }

        UserCredential? userCredential;
        try {
          debug.logEvent('WEB', 'Using Firebase signInWithPopup for web');
          userCredential = await _auth.signInWithPopup(provider);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'popup-blocked' ||
              e.code == 'popup-closed-by-user' ||
              e.code == 'operation-not-supported-in-this-environment' ||
              e.code == 'unauthorized-domain') {
            debug.logEvent('FALLBACK', 'Popup unavailable, using redirect: ${e.code}');
            await _auth.signInWithRedirect(provider);
            return null;
          }
          rethrow;
        }

        if (userCredential.user != null) {
          await _completeGoogleSignIn(userCredential.user!, analyticsMethod: 'google_web');
        }
        return userCredential;
      }

      // ── Native: use google_sign_in plugin ──
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debug.logEvent('CANCELLED', 'User cancelled Google sign-in');
        return null;
      }

      debug.logEvent('TOKEN', 'Got Google user: ${googleUser.email}',
        details: {'displayName': googleUser.displayName ?? 'none'},
      );

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null || idToken == null) {
        final err = 'No Access Token found.';
        debug.logSignInError(err);
        throw err;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      var user = _auth.currentUser;

      if (user == null) {
        debug.logEvent('ANON', 'No current user, signing in anonymously first...');
        await _auth.signInAnonymously();
        user = _auth.currentUser;
        if (user == null) {
          debug.logSignInError('Failed to create anonymous user');
          return null;
        }
      }

      UserCredential? userCredential;

      if (user.isAnonymous) {
        debug.logEvent('LINK', 'Linking anonymous account to Google...',
          details: {'anonUid': user.uid},
        );
        try {
          userCredential = await user.linkWithCredential(credential);
          await _auth.currentUser?.reload();
          debug.logEvent('LINK_OK', 'Account linked successfully!',
            details: {'newUid': userCredential.user?.uid ?? 'unknown'},
          );
        } on FirebaseAuthException catch (e) {
          debug.logEvent('LINK_ERR', 'Link failed: ${e.code} - ${e.message ?? ''}',
            details: {'code': e.code, 'message': e.message ?? ''},
          );
          if (e.code == 'credential-already-in-use' ||
              e.code == 'provider-already-linked') {
            debug.logEvent('FALLBACK', 'Falling back to direct sign-in');
            await _auth.signOut();
            await _auth.signInAnonymously();
            userCredential = await _auth.signInWithCredential(credential);
            debug.logEvent('FALLBACK_OK', 'Direct sign-in succeeded');
          } else {
            debug.logSignInError(e, stackTrace: e.message);
            rethrow;
          }
        }
      } else {
        debug.logEvent('NON_ANON', 'Already signed in non-anonymously, signing out first');
        await _auth.signOut();
        userCredential = await _auth.signInWithCredential(credential);
      }

      if (userCredential.user != null) {
        await _completeGoogleSignIn(userCredential.user!, analyticsMethod: 'google');
      }
      return userCredential;
    } on PlatformException catch (e, stack) {
      print("================ GOOGLE SIGN-IN PLATFORM ERROR ================");
      print("Code: ${e.code}");
      print("Message: ${e.message}");
      print("Details: ${e.details}");
      print("Stacktrace: $stack");
      print("===============================================================");
      debug.logSignInError(e,
        stackTrace: 'Code: ${e.code}\nMessage: ${e.message}\nDetails: ${e.details}',
      );
      return null;
    } catch (e, stack) {
      print("================ GOOGLE SIGN-IN GENERAL ERROR ================");
      print("Error: $e");
      print("Stacktrace: $stack");
      print("==============================================================");
      debug.logSignInError(e, stackTrace: stack.toString());
      return null;
    }
  }

  /// Post-Google-sign-in housekeeping shared by popup, redirect, and boot
  /// resume: backend sync, crypto key, journal pull, analytics, RevenueCat.
  static Future<void> _completeGoogleSignIn(
    User user, {
    required String analyticsMethod,
  }) async {
    final debug = AuthDebugService();
    try {
      await UserService.syncUser(user);
    } catch (e) {
      debug.logEvent('SYNC_ERR', 'Backend sync failed: $e');
    }
    try {
      await CryptoService.fetchAndStoreKey();
    } catch (e) {
      debug.logEvent('SYNC_ERR', 'Crypto key fetch failed: $e');
    }
    try {
      await JournalRemoteStorage.pullAllJournalsToLocal();
      JournalService.notifyJournalsChanged();
    } catch (e) {
      debug.logEvent('SYNC_ERR', 'Journal pull failed: $e');
    }
    AnalyticsService.instance.logEvent('sign_in', params: {'method': analyticsMethod});
    try {
      await RevenueCatService.instance.identify(user.uid);
    } catch (e) {
      debug.logEvent('RC_ERR', 'RevenueCat identify failed: $e');
    }
    debug.logSignInSuccess(details: {
      'uid': user.uid,
      'email': user.email ?? 'none',
      'displayName': user.displayName ?? 'none',
      'platform': kIsWeb ? 'web' : 'native',
    });
  }

  /// On web, completes a Google sign-in that went through the redirect flow
  /// (iOS Safari / blocked popup). Returns the credential if a redirect
  /// sign-in finished, otherwise null. Safe to call on any platform.
  static Future<UserCredential?> completeRedirectSignIn() async {
    if (!kIsWeb) return null;
    final debug = AuthDebugService();
    try {
      final result = await _auth.getRedirectResult();
      final user = result.user;
      if (user != null) {
        debug.logEvent('REDIRECT_OK', 'Redirect sign-in completed for ${user.uid}');
        await _completeGoogleSignIn(user, analyticsMethod: 'google_web');
      }
      return result;
    } on FirebaseAuthException catch (e) {
      debug.logEvent('REDIRECT_ERR', 'getRedirectResult failed: ${e.code}');
      return null;
    } catch (e) {
      debug.logEvent('REDIRECT_ERR', 'getRedirectResult failed: $e');
      return null;
    }
  }

  /// Continue with Email (Signs up if new, signs in if exists)
  static Future<UserCredential?> continueWithEmail(
    String email,
    String password,
  ) async {
    try {
      // Try signing up first in priority
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        await UserService.syncUser(userCredential.user!);
        await CryptoService.fetchAndStoreKey();
        await JournalRemoteStorage.pullAllJournalsToLocal();
        AnalyticsService.instance.logEvent('sign_up', params: {'method': 'email'});
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          // If the user already exists, sign them in
          final userCredential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          if (userCredential.user != null) {
            await UserService.syncUser(userCredential.user!);
            await CryptoService.fetchAndStoreKey();
            await JournalRemoteStorage.pullAllJournalsToLocal();
          }
          return userCredential;
        } catch (innerError) {
          print("Email Sign-In (Fallback) Error: $innerError");
          rethrow;
        }
      } else {
        print("Email Sign-Up Error: $e");
        rethrow;
      }
    } catch (e) {
      print("Email Authentication Error: $e");
      rethrow;
    }
  }

  /// Sign out and re-create anonymous session
  static Future<void> signOut() async {
    AnalyticsService.instance.logEvent('sign_out');
    await RevenueCatService.instance.reset();
    await _auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      print("Google Sign-Out Error: $e");
    }
    await _auth.signInAnonymously();
    await CryptoService.fetchAndStoreKey();
  }
}
