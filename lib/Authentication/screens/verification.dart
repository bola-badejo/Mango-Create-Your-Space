import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Authentication/controllers/auth_controller.dart';
import 'package:mango/Models/animation.dart';
import 'package:mango/Utils/text_field.dart';
import 'package:mango/constants.dart';
import 'package:mango/utils.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late final AuthController _authController;
  final TextEditingController _codeController = TextEditingController();
  final RxBool _isLoading = false.obs;
  
  String verificationId = '';
  bool isPhoneNumberVerification = false;
  bool isPasswordReset = false;

  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();
    
    // Get arguments from navigation
    final args = Get.arguments as Map<String, dynamic>?;
    verificationId = args?['verificationId'] ?? '';
    isPhoneNumberVerification = args?['isPhoneNumberVerification'] ?? false;
    isPasswordReset = args?['isPasswordReset'] ?? false;
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      UtilsService().showSnackbar(
        'Error',
        'Please enter verification code',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (code.length < 6) {
      UtilsService().showSnackbar(
        'Error',
        'Please enter a valid 6-digit code',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      _isLoading.value = true;
      await _authController.verifyCode(
        verificationId,
        code,
        isPhoneNumberVerification,
        context,
      );
    } catch (e) {
      UtilsService().showSnackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
        tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              FadeAnimation(
                0.5,
                Text(
                  'Verification',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              FadeAnimation(
                0.7,
                Text(
                  isPhoneNumberVerification 
                      ? 'Enter the 6-digit code sent to your phone number'
                      : 'Enter the verification code sent to your email',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: MangoPalette.grey600,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              FadeAnimation(
                0.9,
                CustomTextField(
                  placeholder: "Verification Code",
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  leading: const Icon(Icons.security),
                  // maxLength: 6,
                ),
              ),
              
              const SizedBox(height: 32),
              
              FadeAnimation(
                1.1,
                Obx(
                  () => ElevatedButton(
                    onPressed: _isLoading.value ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MangoRadius.md),
                      ),
                      backgroundColor: theme.primaryColor,
                    ),
                    child: _isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(semanticsLabel: 'Loading', 
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            "Verify",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              FadeAnimation(
                1.3,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code?",
                      style: theme.textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: () {
                        // Implement resend logic here
                        UtilsService().showSnackbar(
                          'Info',
                          'Code resent successfully',
                          snackPosition: SnackPosition.BOTTOM,
                          context: context,
                          backgroundColor: Colors.blue,
                          colorText: Colors.white,
                        );
                      },
                      child: Text(
                        "Resend",
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}