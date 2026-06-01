import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'user_service.dart';
import 'auth_debug_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  /// Get current user stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

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
        },
      );

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
          debug.logEvent('LINK_OK', 'Account linked successfully!',
            details: {'newUid': userCredential?.user?.uid ?? 'unknown'},
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

      if (userCredential != null && userCredential.user != null) {
        await UserService.syncUser(userCredential.user!);
        Superwall.shared.identify(userCredential.user!.uid);
        debug.logSignInSuccess(details: {
          'uid': userCredential.user!.uid,
          'email': userCredential.user!.email ?? 'none',
          'displayName': userCredential.user!.displayName ?? 'none',
        });
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
    Superwall.shared.reset();
    await _auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      print("Google Sign-Out Error: $e");
    }
    await _auth.signInAnonymously();
  }
}
