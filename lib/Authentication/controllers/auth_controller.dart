

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mango/App/router/app_routes.dart';
import 'package:mango/AccountSetup/onboarding_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mango/utils.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class AuthController extends GetxController {
  static AuthController get instance => Get.find<AuthController>();
  
  
  FirebaseAuth get auth => FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  
  String _parseFirebaseError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
          return 'Invalid email or password';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later';
        case 'network-request-failed':
          return 'Network error. Please check your connection';
        case 'invalid-email':
          return 'Please enter a valid email address';
        case 'weak-password':
          return 'Password is too weak. Use at least 6 characters';
        case 'email-already-in-use':
          return 'An account with this email already exists';
        case 'operation-not-allowed':
          return 'This authentication method is not enabled';
        case 'requires-recent-login':
          return 'Please sign in again to continue';
        default:
          return error.message ?? 'An error occurred. Please try again';
      }
    }
    return error.toString();
  }

  void _showErrorSnackbar(String message, context) {
    UtilsService().showSnackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.redAccent.withOpacity(0.9),
      context: context,
      colorText: Colors.white,
      borderRadius: 8,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.error_outline, color: Colors.white),
      shouldIconPulse: true,
      
    );
  }

  void _showSuccessSnackbar(String message, context) {
    UtilsService().showSnackbar(
      'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      context: context,
      backgroundColor: MangoPalette.green400.withOpacity(0.9),
      colorText: MangoPalette.black,
      borderRadius: 8,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.check_circle, color: MangoPalette.black),
      shouldIconPulse: true,
      
    );
  }

  Future<void> signUpWithEmailAndPassword(String email, String password, BuildContext context) async {
    try {
      await auth.createUserWithEmailAndPassword(email: email.trim(), password: password.trim());
      // Verification is sent but never blocks getting started.
      try {
        await auth.currentUser!.sendEmailVerification();
      } catch (_) {}
      await OnboardingService.instance.continueAfterSignIn();
    } catch (e) {
      _showErrorSnackbar(_parseFirebaseError(e), context);
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password, BuildContext context) async {
    try {
      await auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());
      await OnboardingService.instance.continueAfterSignIn();
    } catch (e) {
      _showErrorSnackbar(_parseFirebaseError(e), context);
    }
  }

  static bool _googleReady = false;

  /// Google sign-in: a popup on web; google_sign_in 7 (initialise once, then
  /// authenticate and use the ID token) on phones.
  Future<void> signInWithGoogle(context) async {
    try {
      if (kIsWeb) {
        await auth.signInWithPopup(GoogleAuthProvider()..addScope('email'));
      } else {
        final signIn = GoogleSignIn.instance;
        if (!_googleReady) {
          await signIn.initialize();
          _googleReady = true;
        }
        final account = await signIn.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) {
          _showErrorSnackbar('Google sign-in failed. Please try again', context);
          return;
        }
        await auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      }
      await OnboardingService.instance.continueAfterSignIn();
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) _showErrorSnackbar('Google sign-in failed. Please try again', context);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'popup-closed-by-user' && e.code != 'cancelled-popup-request') _showErrorSnackbar(_parseFirebaseError(e), context);
    } catch (e) {
      _showErrorSnackbar(e.toString().contains('network') ? 'Network error. Please check your connection' : 'Google sign-in failed. Please try again', context);
    }
  }

  Future<void> signInWithApple(context) async {
    try {
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      if (apple.identityToken == null) {
        _showErrorSnackbar('Apple sign-in failed. Please try again', context);
        return;
      }
      final credential = OAuthProvider('apple.com').credential(idToken: apple.identityToken, accessToken: apple.authorizationCode);
      final result = await auth.signInWithCredential(credential);
      // Apple shares the name only on the first sign-in: keep it.
      final name = [apple.givenName, apple.familyName].whereType<String>().where((s) => s.isNotEmpty).join(' ');
      if (name.isNotEmpty && (result.user?.displayName ?? '').isEmpty) {
        await result.user?.updateDisplayName(name);
      }
      await OnboardingService.instance.continueAfterSignIn();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled) _showErrorSnackbar('Apple sign-in failed. Please try again', context);
    } catch (e) {
      _showErrorSnackbar(_parseFirebaseError(e), context);
    }
  }

  Future<void> signInWithPhoneNumber(String phoneNumber, BuildContext context) async {
    try {
      String formattedPhoneNumber = phoneNumber.trim();
      await auth.verifyPhoneNumber(
        phoneNumber: formattedPhoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await auth.signInWithCredential(credential);
          await OnboardingService.instance.continueAfterSignIn();
        },
        verificationFailed: (FirebaseAuthException e) {
          _showErrorSnackbar(_parseFirebaseError(e), context);
        },
        codeSent: (String verificationId, int? resendToken) {
          _showSuccessSnackbar('Verification code sent to your phone', context);
          Get.toNamed(AppRoutes.otp, arguments: verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
        timeout: const Duration(seconds: 120),
      );
    } catch (e) {
      _showErrorSnackbar(_parseFirebaseError(e), context);
    }
  }

  Future<void> resetPasswordWithEmail(String email, BuildContext context) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
      _showSuccessSnackbar('Password reset email sent', context);
      Get.toNamed(
        '/verification',
        arguments: {'verificationId': '', 'isPhoneNumberVerification': false},
      );
    } catch (e) {
      _showErrorSnackbar(_parseFirebaseError(e), context);
    }
  }

  Future<void> resetPasswordWithPhoneNumber(String phoneNumber, BuildContext context) async {
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber.trim(),
        verificationCompleted: (PhoneAuthCredential credential) async {
          
        },
        verificationFailed: (FirebaseAuthException e) {
          _showErrorSnackbar(_parseFirebaseError(e), context);
        },
        codeSent: (String verificationId, int? resendToken) {
          _showSuccessSnackbar('Verification code sent', context);
          Get.toNamed(
            '/verification',
            arguments: {
              'verificationId': verificationId,
              'isPhoneNumberVerification': true,
            },
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
        timeout: const Duration(seconds: 120),
      );
    } catch (e) {
      _showErrorSnackbar(_parseFirebaseError(e), context);
    }
  }

  Future<void> verifyCode(
    String verificationId,
    String code,
    bool isPhoneNumberVerification,
    BuildContext context,
  ) async {
    try {
      if (isPhoneNumberVerification) {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: code,
        );
        await auth.signInWithCredential(credential);
        _showSuccessSnackbar('Phone number verified successfully', context);
      } else {
        await auth.checkActionCode(code);
        await auth.applyActionCode(code);
        _showSuccessSnackbar('Email verified successfully', context);
      }
      if (isPhoneNumberVerification) {
        await OnboardingService.instance.continueAfterSignIn();
      } else {
        Get.offNamed('/home');
      }
    } catch (e) {
      _showErrorSnackbar(_parseFirebaseError(e), context);
    }
  }

  Future<void> signOut(BuildContext context) async {
    try {
      await auth.signOut();
      await _googleSignIn.signOut();
      _showSuccessSnackbar('Signed out successfully', context);
    } catch (e) {
      _showErrorSnackbar(_parseFirebaseError(e), context);
    }
  }
}