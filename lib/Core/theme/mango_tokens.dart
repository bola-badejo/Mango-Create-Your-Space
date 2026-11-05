// Mango design tokens: spacing, radius, motion and component dimensions.
// Source of truth: "Mango Design System: Specification and Implementation
// Guide", Section B. Screens must use these instead of literal values.
import 'package:flutter/animation.dart';

/// 4-point spacing scale.
abstract final class MangoSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;
}

/// Corner radii. Shape signals role; do not invent new values.
abstract final class MangoRadius {
  static const double xs = 4; // badges, progress, tags
  static const double sm = 8; // chips, small thumbnails, tooltips
  static const double md = 12; // inputs, media tiles, cards
  static const double lg = 20; // bottom sheets, dialogs
  static const double pill = 999; // buttons, search, segmented controls
}

/// Component dimensions shared across the library.
abstract final class MangoSize {
  /// Minimum touch target (Android 48 dp; also satisfies iOS 44 pt).
  static const double minTouchTarget = 48;
  static const double buttonLarge = 52;
  static const double buttonMedium = 44;
  static const double inputHeight = 52;
  static const double iconSmall = 18;
  static const double icon = 24;
  static const double focusRingWidth = 2;

  /// Maximum widths so content never stretches indefinitely.
  static const double maxFeedWidth = 640;
  static const double maxReadingWidth = 720;
  static const double maxGridWidth = 1200;
}

/// Motion tokens. Ordinary interactions stay under 300 ms; `slow` is
/// reserved for shared-element transitions of large media.
abstract final class MangoMotionTokens {
  static const Duration instant = Duration(milliseconds: 100); // press feedback
  static const Duration fast = Duration(milliseconds: 150); // icon swaps, focus
  static const Duration base = Duration(milliseconds: 200); // small components
  static const Duration moderate = Duration(milliseconds: 250); // menus, sheets
  static const Duration slow = Duration(milliseconds: 400); // shared elements only

  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve enter = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve exit = Cubic(0.3, 0.0, 0.8, 0.15);
}
