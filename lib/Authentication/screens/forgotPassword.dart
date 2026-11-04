import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Authentication/controllers/auth_controller.dart';

class ForgotPasswordScreen extends StatefulWidget {
  ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final AuthController _authController;

  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Forgot Password"), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Reset your password",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cs.onBackground,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Enter your email address and we’ll send you a password reset link.",
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withOpacity(0.8),
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: _emailController,
              style: TextStyle(color: cs.onBackground),
              decoration: InputDecoration(
                labelText: "Email Address",
                prefixIcon: const Icon(Icons.email_outlined),
                filled: true,
                fillColor: cs.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  _authController.resetPasswordWithEmail(
                    _emailController.text.trim(), 
                    context
                  );
                },
                child: const Text("Send Reset Link"),
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: TextButton(
                onPressed: () {
                  Get.toNamed('/phone-number-forgot-password');
                },
                child: const Text("Use Phone Number Instead"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhoneNumberForgotPasswordScreen extends StatefulWidget {
  PhoneNumberForgotPasswordScreen({super.key});

  @override
  State<PhoneNumberForgotPasswordScreen> createState() =>
      _PhoneNumberForgotPasswordScreenState();
}

class _PhoneNumberForgotPasswordScreenState
    extends State<PhoneNumberForgotPasswordScreen> {
  final TextEditingController _phoneController = TextEditingController();

  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Reset with Phone Number"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Verify your phone",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cs.onBackground,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "We will send you an OTP to reset your password.",
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.8),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: cs.onBackground),
              decoration: InputDecoration(
                labelText: "Phone Number",
                prefixIcon: const Icon(Icons.phone_android_outlined),
                filled: true,
                fillColor: cs.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  _authController.resetPasswordWithPhoneNumber(
                    _phoneController.text.trim(),
                    context
                  );
                },
                child: const Text("Send OTP"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VerificationScreen extends StatefulWidget {
  VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final String verificationId = Get.arguments['verificationId'];
    final bool isPhone = Get.arguments['isPhoneNumberVerification'];

    return Scaffold(
      appBar: AppBar(title: const Text("Verification"), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Enter Verification Code",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cs.onBackground,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              isPhone
                  ? "We sent an OTP to your phone."
                  : "Enter the code sent to your email.",
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.8),
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: cs.onBackground),
              decoration: InputDecoration(
                labelText: isPhone ? "OTP" : "Verification Code",
                prefixIcon: const Icon(Icons.lock_outline),
                filled: true,
                fillColor: cs.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  _authController.verifyCode(
                    verificationId,
                    _otpController.text.trim(),
                    isPhone,
                    context
                  );
                },
                child: const Text("Verify"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
