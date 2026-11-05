import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/AccountSetup/onboarding_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/utils.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class OTPScreen extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _otpController = TextEditingController();

  OTPScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String verificationId = Get.arguments as String;

    return Scaffold(
      backgroundColor: MangoPalette.black,
      appBar: AppBar(
        backgroundColor: MangoPalette.black,
        elevation: 0,
        title: const Text(
          'OTP Verification',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            
            const Text(
              "Enter the 6-digit code sent to your phone",
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),

            const SizedBox(height: 30),

            
            TextFormField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                counterText: "",
                filled: true,
                fillColor: Colors.white10,
                labelText: "OTP Code",
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: "••••••",
                hintStyle: const TextStyle(color: Colors.white30),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(MangoRadius.md),
                ),
              ),
            ),

            const SizedBox(height: 40),

            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  verifyOTP(verificationId, _otpController.text.trim(), context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: MangoPalette.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MangoRadius.md),
                  ),
                ),
                child: const Text(
                  'Verify OTP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> verifyOTP(String verificationId, String otp, BuildContext context) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      await _auth.signInWithCredential(credential);
      await OnboardingService.instance.continueAfterSignIn();
    } catch (e) {
      UtilsService().showSnackbar(
        'Verification Failed',
        e.toString(),
        backgroundColor: Colors.white,
        context: context,
        colorText: MangoPalette.black,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
