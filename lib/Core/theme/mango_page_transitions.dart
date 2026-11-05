// Page transitions for routes pushed with MaterialPageRoute (and GetX's
// Transition.native). Platform-native movement, replaced by a short
// cross-fade when the user has asked to reduce motion.
import 'package:flutter/material.dart';

class MangoPageTransitionsBuilder extends PageTransitionsBuilder {
  const MangoPageTransitionsBuilder(this.platform);

  final PageTransitionsBuilder platform;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return FadeTransition(opacity: animation, child: child);
    }
    return platform.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

const PageTransitionsTheme mangoPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android:
        MangoPageTransitionsBuilder(ZoomPageTransitionsBuilder()),
    TargetPlatform.iOS:
        MangoPageTransitionsBuilder(CupertinoPageTransitionsBuilder()),
    TargetPlatform.macOS:
        MangoPageTransitionsBuilder(CupertinoPageTransitionsBuilder()),
    TargetPlatform.windows:
        MangoPageTransitionsBuilder(FadeUpwardsPageTransitionsBuilder()),
    TargetPlatform.linux:
        MangoPageTransitionsBuilder(FadeUpwardsPageTransitionsBuilder()),
    TargetPlatform.fuchsia:
        MangoPageTransitionsBuilder(ZoomPageTransitionsBuilder()),
  },
);
