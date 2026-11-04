

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mango/utils.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
      backgroundColor: Colors.greenAccent.withOpacity(0.9),
      colorText: Colors.black,
      borderRadius: 8,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
      icon: const Icon(Icons.check_circle, color: Colors.black),
      shouldIconPulse: true,
      
    );
  }

  Future<void> signUpWithEmailAndPassword(String email, String password, BuildContext context) async {
    try {
      await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      await auth.currentUser!.sendEmailVerification();
      _showSuccessSnackbar('Account created! Please verify your email', context);
      Get.offNamed('/add-details');
    } catch (e) {
      _showErrorSnackbar(_parseFirebaseError(e), context);
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password, BuildContext context) async {
    try {
      final userCredential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      if (!userCredential.user!.emailVerified) {
        await auth.currentUser!.sendEmailVerification();
        _showSuccessSnackbar('Verification email sent. Please check your inbox', context);
      }
      
      Get.offNamed('/home');
    } catch (e) {
      _showErrorSnackbar(_parseFirebaseError(e), context);
    }
  }

  Future<void> signInWithGoogle(context) async {
  try {
    
    final GoogleSignIn signIn = GoogleSignIn.instance;

    
    final GoogleSignInAccount? googleUser = await signIn.authenticate();

    if (googleUser == null) {
      _showErrorSnackbar('Google sign-in was cancelled', context);
      return;
    }

    
    final GoogleSignInClientAuthorization? googleAuth = await googleUser
        .authorizationClient
        .authorizationForScopes(['email', 'profile']);

    
    if (googleAuth == null) {
      _showErrorSnackbar('Google sign-in failed. No authorization received', context);
      return;
    }

    
    final String? idToken = googleAuth.accessToken;
    final String? accessToken = googleAuth.accessToken;

    if (idToken == null) {
      _showErrorSnackbar('Google sign-in failed. No ID token received', context);
      return;
    }

    
    final credential = GoogleAuthProvider.credential(
      accessToken: accessToken, 
    );

    
    
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

    if (userCredential.user != null) {
      _showSuccessSnackbar('Signed in with Google successfully', context);
      Get.offNamed('/add-details');
    } else {
      _showErrorSnackbar('Google sign-in failed. Please try again', context);
    }
  } on FirebaseAuthException catch (e) {
    _showErrorSnackbar(_parseFirebaseError(e), context);
  } catch (e) {
    if (e.toString().contains('canceled')) {
      _showErrorSnackbar('Google sign-in was cancelled', context);
    } else if (e.toString().contains('network')) {
      _showErrorSnackbar('Network error. Please check your connection', context);
    } else {
      _showErrorSnackbar('Google sign-in failed: ${e.toString()}', context);
    }
  }
}

  Future<void> signInWithApple(context) async {
    try {
      final AuthorizationCredentialAppleID appleIdCredential =
          await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      if (appleIdCredential.identityToken == null) {
        _showErrorSnackbar('Apple sign-in failed. Please try again', context);
        return;
      }
      
      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final OAuthCredential credential = oAuthProvider.credential(
        idToken: appleIdCredential.identityToken,
        accessToken: appleIdCredential.authorizationCode,
      );
      
      await auth.signInWithCredential(credential);
      
      _showSuccessSnackbar('Signed in with Apple successfully', context);
      Get.offNamed('/add-details');
    } on SignInWithAppleException catch (_) {
      _showErrorSnackbar('Apple sign-in was cancelled', context);
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
          _showSuccessSnackbar('Phone authentication successful', context);
          Get.offNamed('/home');
        },
        verificationFailed: (FirebaseAuthException e) {
          _showErrorSnackbar(_parseFirebaseError(e), context);
        },
        codeSent: (String verificationId, int? resendToken) {
          _showSuccessSnackbar('Verification code sent to your phone', context);
          Get.offNamed('/otp-screen', arguments: verificationId);
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
      Get.offNamed('/home');
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