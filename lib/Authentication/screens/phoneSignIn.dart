import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Authentication/controllers/auth_controller.dart';
import 'package:mango/utils.dart';

import '../../Models/animation.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class PhoneSignInScreen extends StatefulWidget {
  static String routeName = '/phone';
  const PhoneSignInScreen({super.key});

  @override
  State<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends State<PhoneSignInScreen> {
  final TextEditingController phoneController = TextEditingController();
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MangoPalette.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeAnimation(
                1.0,
                const Text(
                  "Phone Sign-In",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              FadeAnimation(
                1.2,
                const Text(
                  "Enter your phone number to receive a verification code.",
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),

              const SizedBox(height: 40),

              FadeAnimation(
                1.3,
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Phone Number",
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: "e.g. 08012345678",
                    hintStyle: TextStyle(color: Colors.white24),

                    filled: true,
                    fillColor: Colors.white12,

                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 18,
                      horizontal: 16,
                    ),

                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              FadeAnimation(
                1.6,
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final phone = phoneController.text.trim();
                      if (phone.isNotEmpty) {
                        _authController.signInWithPhoneNumber(phone, context);
                      } else {
                        UtilsService().showSnackbar(
                          "Empty Field",
                          "Please enter a phone number",
                          snackPosition: SnackPosition.BOTTOM,
                          context: context,
                          backgroundColor: Colors.white,
                          colorText: MangoPalette.black,
                        );
                      }
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
                      "Continue",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
