import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mango/Models/animation.dart';

import '../../constants.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class Authenticate extends StatefulWidget {
  const Authenticate({super.key});

  @override
  _AuthenticateState createState() => _AuthenticateState();
}

class _AuthenticateState extends State<Authenticate> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color background = isDark ? MangoPalette.black : Colors.white;
    final Color textColor = isDark ? Colors.white : MangoPalette.black;
    final Color borderColor = isDark ? Colors.white70 : Colors.black87;
    final Color fillColor = isDark ? Colors.white : MangoPalette.black;
    final Color fillTextColor = isDark ? MangoPalette.black : Colors.white;

    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: background,
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            
            
            ReverseFadeAnimation(
              1,
              Text(
                'this is',
                style: splashText2.copyWith(color: textColor),
              ),
            ),

            const SizedBox(height: 6),

            
            ReverseFadeAnimation(
              1.5,
              Text(
                'mango',
                style: splashText.copyWith(color: textColor),
              ),
            ),

            const SizedBox(height: 6),

            
            ReverseFadeAnimation(
              2,
              Text(
                "Create your space.\n\nConnect with people you can bond with. Don't believe all you read, see for yourself!",
                textWidthBasis: TextWidthBasis.longestLine,
                overflow: TextOverflow.fade,
                maxLines: 4,
                textAlign: TextAlign.left,
                style: labelBody.copyWith(color: textColor),
              ),
            ),

            const SizedBox(height: 30),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                
                
                ReverseFadeAnimation(
                  2.5,
                  InkWell(
                    onTap: () => Get.toNamed('/signup'),
                    child: Container(
                      width: width / 2.5,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: borderColor,
                          width: 2,
                        ),
                        color: Colors.transparent,
                      ),
                      child: Text(
                        'Sign Up',
                        style: labelBody.copyWith(color: textColor),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                
                ReverseFadeAnimation(
                  3,
                  InkWell(
                    onTap: () => Get.toNamed('/login'),
                    child: Container(
                      width: width / 2.5,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(25),
                        color: fillColor,
                      ),
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          fontSize: 14,
                          color: fillTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ],
        ),
      ),
    );
  }
}
