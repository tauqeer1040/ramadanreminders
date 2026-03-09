import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'user_service.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  // Server Client ID for Google Sign In
  static const String serverClientId =
      '470720192448-pi62jpdgfm3g1u7bml3adgomr63qsp0b.apps.googleusercontent.com';

  /// Get current user stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();
  static User? get currentUser => _auth.currentUser;

  /// Sign in with Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: serverClientId,
      );
      final googleUser = await googleSignIn.signIn();
      final googleAuth = await googleUser?.authentication;
      final accessToken = googleAuth?.accessToken;
      final idToken = googleAuth?.idToken;

      if (accessToken == null || idToken == null) {
        throw 'No Access Token found.';
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await UserService.syncUser(userCredential.user!);
      }
      return userCredential;
    } on PlatformException catch (e, stack) {
      print("================ GOOGLE SIGN-IN PLATFORM ERROR ================");
      print("Code: ${e.code}");
      print("Message: ${e.message}");
      print("Details: ${e.details}");
      print("Stacktrace: $stack");
      print("===============================================================");
      return null;
    } catch (e, stack) {
      print("================ GOOGLE SIGN-IN GENERAL ERROR ================");
      print("Error: $e");
      print("Stacktrace: $stack");
      print("==============================================================");
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

  /// Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (e) {
      print("Google Sign-Out Error: $e");
    }
  }
}
