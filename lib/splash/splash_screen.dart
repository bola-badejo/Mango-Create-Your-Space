import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mango/App/router/app_routes.dart';
import 'package:mango/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  double _scale = 0.0;
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();

    
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        _scale = 1.0;
        _opacity = 1.0;
      });
    });

    
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await Future.delayed(const Duration(seconds: 2)); 
      await _checkFirstTimeAndNavigate();
    } catch (e) {
      if (mounted) {
        UtilsService().showSnackbar('Error', 'Failed to initialize app: $e',
            snackPosition: SnackPosition.BOTTOM, context: context);
        Get.offAllNamed(AppRoutes.welcome);
      }
    }
  }

  Future<void> _checkFirstTimeAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isFirstTime = prefs.getBool('isFirstTime') ?? true;
    final User? user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    if (isFirstTime) {
      await prefs.setBool('isFirstTime', false);
      Get.offAllNamed(AppRoutes.onboarding);
    } else if (user != null && user.uid.isNotEmpty) {
      Get.offAllNamed(AppRoutes.home);
    } else {
      Get.offAllNamed(AppRoutes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: _scale,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _opacity,
                duration: const Duration(milliseconds: 800),
                child: Image.asset(
                  "asset/images/mango.png",
                  width: 60,
                  height: 60,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error, size: 60),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              opacity: _opacity,
              duration: const Duration(milliseconds: 1200),
              child: Text(
                'Create your Space..',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
