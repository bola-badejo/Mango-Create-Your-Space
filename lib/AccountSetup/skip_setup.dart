import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/constants.dart';
import 'interests.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class SkipSetup extends StatefulWidget {
  final String? uid;
  const SkipSetup({super.key, required this.uid});

  @override
  _SkipSetupState createState() => _SkipSetupState();
}

class _SkipSetupState extends State<SkipSetup> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color backgroundColor = isDark ? MangoPalette.grey900 : MangoPalette.grey50;
    final Color textColor = isDark ? Colors.white : MangoPalette.black;
    final Color buttonColor = isDark ? MangoPalette.grey700 : MangoPalette.grey300;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () {
              Get.offNamed('home');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.skip_next,
                  color: textColor,
                  size: 22,
                ),
                const SizedBox(width: 5.0),
                Text(
                  "Skip",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(width: 10.0),
              ],
            ),
          )
        ],
      ),
      extendBodyBehindAppBar: true,
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 30),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 130),
              Text(
                "Your Space is almost ready.",
                style: headingextStyle.copyWith(color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  "You can skip and set up your interests later and explore Mango first. The choice is yours.",
                  style: postTextBoxHint.copyWith(color: textColor.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
              
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.offNamed('home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.skip_next,
                        color: textColor,
                        size: 22,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        "Skip for now",
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const Interests()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MangoPalette.green500,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(MangoRadius.md),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 8.0),
                      Text(
                        "Set up interests",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}