import 'package:expansion_tile_card/expansion_tile_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Authentication/controllers/auth_controller.dart';
import 'package:mango/Models/animation.dart';
import 'package:mango/Notifications/notifications_controller.dart';
import 'package:mango/utils.dart';

import '../../constants.dart';
import '../../Utils/text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final RxBool _isLoading = false.obs;

  final RxBool _isEmailLoading = false.obs;
  final RxBool _isPhoneLoading = false.obs;
  final RxBool _isGoogleLoading = false.obs;
  final RxBool _isAppleLoading = false.obs;

  final GlobalKey<ExpansionTileCardState> cardA = GlobalKey();
  final GlobalKey<ExpansionTileCardState> cardB = GlobalKey();

  late final AuthController _authController;

  final notificationController = Get.find<NotificationController>();


  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();
    notificationController.requestPermissionIfNeeded();
    notificationController.debugCheckTokenStorage();
  }

  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackbar('Please fill in all fields', isError: true);
      return;
    }

    try {
      _isEmailLoading.value = true;
      await _authController.signInWithEmailAndPassword(email, password, context);
    } catch (e) {
    } finally {
      _isEmailLoading.value = false;
    }
  }

  void _phoneLogin() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      _showSnackbar('Please enter your phone number', isError: true);
      return;
    }

    try {
      _isPhoneLoading.value = true;
      await _authController.signInWithPhoneNumber(phone, context);
    } catch (e) {
    } finally {
      _isPhoneLoading.value = false;
    }
  }

  void _googleSignIn() async {
    try {
      _isGoogleLoading.value = true;
      await _authController.signInWithGoogle(context);
    } catch (e) {
    } finally {
      _isGoogleLoading.value = false;
    }
  }

  void _appleSignIn() async {
    try {
      _isAppleLoading.value = true;
      await _authController.signInWithApple(context);
    } catch (e) {
    } finally {
      _isAppleLoading.value = false;
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    UtilsService().showSnackbar(
      isError ? 'Error' : 'Success',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError
          ? Colors.redAccent.withOpacity(0.9)
          : Colors.greenAccent.withOpacity(0.9),
      colorText: isError ? Colors.white : Colors.black,
      context: context,
      borderRadius: 8,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
      icon: Icon(
        isError ? Icons.error_outline : Icons.check_circle,
        color: isError ? Colors.white : Colors.black,
      ),
      shouldIconPulse: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 120),

              const FadeAnimation(
                1,
                Text(
                  'welcome',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    letterSpacing: 1,
                  ),
                ),
              ),
              FadeAnimation(
                1.1,
                GestureDetector(
                  onTap: () => Get.toNamed('/space-home'),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              FadeAnimation(
                1.2,
                ExpansionTileCard(
                  key: cardA,
                  elevation: 0,
                  baseColor: Colors.white10,
                  expandedColor: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                  leading: const CircleAvatar(
                    backgroundColor: Colors.white12,
                    child: Icon(Icons.mail, size: 18, color: Colors.white),
                  ),
                  title: const Text(
                    'With email',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'sign in using your email and password',
                    style: TextStyle(fontSize: 10, color: Colors.white54),
                  ),
                  children: <Widget>[
                    const Divider(color: Colors.white12, thickness: 0.5),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20.0,
                        vertical: 26.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          FadeAnimation(
                            1.2,
                            CustomTextField(
                              placeholder: "your email",
                              controller: _emailController,
                              leading: const Icon(
                                Icons.person,
                                color: Colors.white54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          FadeAnimation(
                            1.2,
                            CustomTextField(
                              placeholder: "*******",
                              controller: _passwordController,
                              isPassword: true,
                              leading: const Icon(
                                Icons.lock,
                                color: Colors.white54,
                              ),
                            ),
                          ),

                          const SizedBox(height: 22),

                          FadeAnimation(
                            1.2,
                            GestureDetector(
                              onTap: () => Get.toNamed('/forgot-password'),
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          FadeAnimation(
                            1.5,
                            Obx(() {
                              return SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isEmailLoading.value
                                      ? null
                                      : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isEmailLoading.value
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          "Sign In",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              Center(
                child: FadeAnimation(
                  1.4,
                  Text(
                    "Alternative authentication",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 26),

              // FadeAnimation(
              //   1.3,
              //   ExpansionTileCard(
              //     key: cardB,
              //     elevation: 0,
              //     baseColor: Colors.white10,
              //     expandedColor: Colors.white12,
              //     borderRadius: BorderRadius.circular(12),
              //     leading: const CircleAvatar(
              //       backgroundColor: Colors.white12,
              //       child: Icon(Icons.phone, size: 18, color: Colors.white),
              //     ),
              //     title: const Text(
              //       'With phone number',
              //       style: TextStyle(
              //         fontSize: 12,
              //         color: Colors.white,
              //         fontWeight: FontWeight.w600,
              //       ),
              //     ),
              //     subtitle: const Text(
              //       'sign in using your phone number',
              //       style: TextStyle(fontSize: 10, color: Colors.white54),
              //     ),
              //     children: <Widget>[
              //       const Divider(color: Colors.white12, thickness: 0.5),

              //       Padding(
              //         padding: const EdgeInsets.symmetric(
              //           horizontal: 20.0,
              //           vertical: 26.0,
              //         ),
              //         child: Column(
              //           crossAxisAlignment: CrossAxisAlignment.start,
              //           children: <Widget>[
              //             FadeAnimation(
              //               1.2,
              //               CustomTextField(
              //                 placeholder: "Enter phone number",
              //                 controller: _phoneController,
              //                 leading: const Icon(
              //                   Icons.phone,
              //                   color: Colors.white54,
              //                 ),
              //                 keyboardType: TextInputType.phone,
              //               ),
              //             ),
              //             const SizedBox(height: 28),

              //             FadeAnimation(
              //               1.5,
              //               Obx(() {
              //                 return SizedBox(
              //                   width: double.infinity,
              //                   child: ElevatedButton(
              //                     onPressed: _isPhoneLoading.value
              //                         ? null
              //                         : _phoneLogin,
              //                     style: ElevatedButton.styleFrom(
              //                       backgroundColor: Colors.white,
              //                       foregroundColor: Colors.black,
              //                       padding: const EdgeInsets.symmetric(
              //                         vertical: 15,
              //                       ),
              //                       shape: RoundedRectangleBorder(
              //                         borderRadius: BorderRadius.circular(12),
              //                       ),
              //                     ),
              //                     child: _isPhoneLoading.value
              //                         ? const SizedBox(
              //                             width: 20,
              //                             height: 20,
              //                             child: CircularProgressIndicator(
              //                               strokeWidth: 2,
              //                             ),
              //                           )
              //                         : const Text(
              //                             "Sign In",
              //                             style: TextStyle(
              //                               fontSize: 16,
              //                               fontWeight: FontWeight.w600,
              //                             ),
              //                           ),
              //                   ),
              //                 );
              //               }),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ],
              //   ),
              // ),

              // const SizedBox(height: 26),

              // Obx(() {
              //   return FadeAnimation(
              //     1.4,
              //     GestureDetector(
              //       onTap: _isGoogleLoading.value ? null : _googleSignIn,
              //       child: Container(
              //         padding: const EdgeInsets.symmetric(
              //           vertical: 14,
              //           horizontal: 16,
              //         ),
              //         decoration: BoxDecoration(
              //           color: Colors.white10,
              //           borderRadius: BorderRadius.circular(12),
              //         ),
              //         child: Row(
              //           children: [
              //             if (_isGoogleLoading.value)
              //               const SizedBox(
              //                 width: 20,
              //                 height: 20,
              //                 child: CircularProgressIndicator(
              //                   strokeWidth: 2,
              //                   color: Colors.white,
              //                 ),
              //               )
              //             else
              //               Image.asset("asset/images/google.png", width: 28),
              //             const SizedBox(width: 16),
              //             Text(
              //               "Sign in with Google",
              //               style: TextStyle(
              //                 color: _isGoogleLoading.value
              //                     ? Colors.white54
              //                     : Colors.white,
              //                 fontSize: 14,
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //   );
              // }),

              // const SizedBox(height: 16),

              // Obx(() {
              //   return FadeAnimation(
              //     1.5,
              //     GestureDetector(
              //       onTap: _isAppleLoading.value ? null : _appleSignIn,
              //       child: Container(
              //         padding: const EdgeInsets.symmetric(
              //           vertical: 14,
              //           horizontal: 16,
              //         ),
              //         decoration: BoxDecoration(
              //           color: Colors.white10,
              //           borderRadius: BorderRadius.circular(12),
              //         ),
              //         child: Row(
              //           children: [
              //             if (_isAppleLoading.value)
              //               const SizedBox(
              //                 width: 20,
              //                 height: 20,
              //                 child: CircularProgressIndicator(
              //                   strokeWidth: 2,
              //                   color: Colors.white,
              //                 ),
              //               )
              //             else
              //               Image.asset("asset/images/apple.png", width: 28),
              //             const SizedBox(width: 16),
              //             Text(
              //               "Sign in with iCloud",
              //               style: TextStyle(
              //                 color: _isAppleLoading.value
              //                     ? Colors.white54
              //                     : Colors.white,
              //                 fontSize: 14,
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //   );
              // }),

              // const SizedBox(height: 26),

              FadeAnimation(
                1.3 ,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account?",
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => Get.offNamed('/signup'),
                      child: const Text(
                        "Sign up",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}
