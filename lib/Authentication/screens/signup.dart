import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Authentication/controllers/auth_controller.dart';
import 'package:mango/Models/animation.dart';
import 'package:mango/Notifications/notifications_controller.dart';
import 'package:mango/utils.dart';

import '../../constants.dart';
import '../../Utils/text_field.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  late final AuthController _authController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final RxBool _isLoading = false.obs;

  final GlobalKey<ExpansionTileCardState> emailTileKey = GlobalKey();
  final GlobalKey<ExpansionTileCardState> phoneTileKey = GlobalKey();
  final notificationController = Get.find<NotificationController>(); 

  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();
    notificationController.requestPermissionIfNeeded();
    notificationController.debugCheckTokenStorage();
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      UtilsService().showSnackbar(
        'Error',
        'Please fill in all fields',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (password != confirmPassword) {
      UtilsService().showSnackbar(
        'Error',
        'Passwords do not match',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      _isLoading.value = true;
      await _authController.signUpWithEmailAndPassword(email, password, context);
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

  Future<void> _phoneSignUp() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      UtilsService().showSnackbar(
        'Error',
        'Please enter a phone number',
        snackPosition: SnackPosition.BOTTOM,
        context: context,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      _isLoading.value = true;
      await _authController.signInWithPhoneNumber(phone, context);
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

  Future<void> _signInWithGoogle() async {
    try {
      _isLoading.value = true;
      await _authController.signInWithGoogle(context);
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

  Future<void> _signInWithApple() async {
    try {
      _isLoading.value = true;
      await _authController.signInWithApple(context);
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),

              const FadeAnimation(0.9, Text('Welcome', style: textHeader2)),
              const FadeAnimation(
                1.0,
                Text('Create your account', style: textHeader),
              ),
              const SizedBox(height: 32),

              FadeAnimation(
                1.1,
                ExpansionTileCard(
                  key: emailTileKey,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  baseColor: theme.cardColor,
                  expandedColor: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  leading: CircleAvatar(
                    backgroundColor: theme.primaryColor,
                    child: const Icon(Icons.mail, color: Colors.white),
                  ),
                  title: Text(
                    'Sign up with Email',
                    style:
                        theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ) ??
                        const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'Use your email and password',
                    style: theme.textTheme.bodySmall,
                  ),
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          CustomTextField(
                            placeholder: "Email",
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            leading: const Icon(Icons.person),
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            placeholder: "Password",
                            controller: _passwordController,
                            isPassword: true,
                            leading: const Icon(Icons.lock),
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            placeholder: "Confirm Password",
                            controller: _confirmPasswordController,
                            isPassword: true,
                            leading: const Icon(Icons.lock_outline),
                          ),
                          const SizedBox(height: 24),

                          Obx(
                            () => ElevatedButton(
                              onPressed: _isLoading.value ? null : _signUp,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 55),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading.value
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Text("Sign Up"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // FadeAnimation(
              //   1.2,
              //   Row(
              //     children: [
              //       Expanded(child: Divider(color: theme.dividerColor)),
              //       const Padding(
              //         padding: EdgeInsets.symmetric(horizontal: 12),
              //         child: Text("or"),
              //       ),
              //       Expanded(child: Divider(color: theme.dividerColor)),
              //     ],
              //   ),
              // ),
              // const SizedBox(height: 32),

              // FadeAnimation(
              //   1.3,
              //   ExpansionTileCard(
              //     key: phoneTileKey,
              //     elevation: 0,
              //     shadowColor: Colors.transparent,
              //     baseColor: theme.cardColor,
              //     expandedColor: theme.cardColor,
              //     borderRadius: BorderRadius.circular(16),
              //     leading: CircleAvatar(
              //       backgroundColor: theme.primaryColor,
              //       child: const Icon(Icons.phone, color: Colors.white),
              //     ),
              //     title: Text(
              //       'Sign up with Phone',
              //       style:
              //           theme.textTheme.bodyMedium?.copyWith(
              //             fontWeight: FontWeight.w700,
              //           ) ??
              //           const TextStyle(fontWeight: FontWeight.w700),
              //     ),
              //     subtitle: Text(
              //       'Use your phone number',
              //       style: theme.textTheme.bodySmall,
              //     ),
              //     children: [
              //       const Divider(height: 1),
              //       Padding(
              //         padding: const EdgeInsets.all(16.0),
              //         child: Column(
              //           children: [
              //             CustomTextField(
              //               placeholder: "Phone number",
              //               controller: _phoneController,
              //               keyboardType: TextInputType.phone,
              //               leading: const Icon(Icons.phone),
              //             ),
              //             const SizedBox(height: 24),

              //             Obx(
              //               () => ElevatedButton(
              //                 onPressed: _isLoading.value ? null : _phoneSignUp,
              //                 style: ElevatedButton.styleFrom(
              //                   minimumSize: const Size(double.infinity, 55),
              //                   shape: RoundedRectangleBorder(
              //                     borderRadius: BorderRadius.circular(12),
              //                   ),
              //                 ),
              //                 child: _isLoading.value
              //                     ? const SizedBox(
              //                         height: 20,
              //                         width: 20,
              //                         child: CircularProgressIndicator(
              //                           strokeWidth: 2,
              //                           valueColor:
              //                               AlwaysStoppedAnimation<Color>(
              //                                 Colors.white,
              //                               ),
              //                         ),
              //                       )
              //                     : const Text("Continue"),
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ],
              //   ),
              // ),

              // const SizedBox(height: 32),

              // FadeAnimation(
              //   1.4,
              //   Column(
              //     children: [
              //       _socialButton(
              //         icon: "asset/images/google.png",
              //         text: "Sign up with Google",
              //         onTap: _signInWithGoogle,
              //       ),
              //       const SizedBox(height: 16),
              //       _socialButton(
              //         icon: "asset/images/apple.png",
              //         text: "Sign up with iCloud",
              //         onTap: _signInWithApple,
              //       ),
              //     ],
              //   ),
              // ),

              const SizedBox(height: 32),

              FadeAnimation(
                1.2,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Already have an account?",
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => Get.toNamed('/login'),
                      child: Text(
                        "Login",
                        style:
                            theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ) ??
                            const TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
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

  Widget _socialButton({
    required String icon,
    required String text,
    required Function() onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(.3)),
        ),
        child: Row(
          children: [
            Image.asset(icon, height: 26, width: 26),
            const SizedBox(width: 16),
            Text(text, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
