// Type scale: Poppins in three weights (400, 500, 600), bundled as assets.
// Scripts Poppins does not cover (Arabic, Cyrillic, CJK and others) fall
// back to the platform's system fonts on iOS and Android; Flutter web
// fetches Noto fallbacks automatically.
import 'package:flutter/material.dart';

abstract final class MangoTypography {
  static const String family = 'Poppins';

  static TextStyle _style(
    double size,
    double lineHeight,
    FontWeight weight,
    double tracking,
  ) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: tracking,
        leadingDistribution: TextLeadingDistribution.even,
      );

  /// Maps Mango styles onto Material's TextTheme slots so existing
  /// `Theme.of(context).textTheme` call sites pick them up.
  static TextTheme textTheme(Color primary) => TextTheme(
        displayLarge: _style(36, 44, FontWeight.w600, -0.5), // display.large
        displayMedium: _style(32, 40, FontWeight.w600, -0.25), // display.medium
        displaySmall: _style(28, 36, FontWeight.w600, 0), // heading.1
        headlineLarge: _style(28, 36, FontWeight.w600, 0), // heading.1
        headlineMedium: _style(24, 32, FontWeight.w600, 0), // heading.2
        headlineSmall: _style(20, 28, FontWeight.w500, 0), // heading.3
        titleLarge: _style(18, 26, FontWeight.w600, 0), // title
        titleMedium: _style(16, 24, FontWeight.w500, 0),
        titleSmall: _style(14, 20, FontWeight.w500, 0.1),
        bodyLarge: _style(16, 24, FontWeight.w400, 0), // body.large
        bodyMedium: _style(14, 20, FontWeight.w400, 0.1), // body
        bodySmall: _style(12, 16, FontWeight.w400, 0.2), // caption
        labelLarge: _style(13, 18, FontWeight.w500, 0.1), // label
        labelMedium: _style(12, 16, FontWeight.w500, 0.2),
        labelSmall: _style(12, 16, FontWeight.w500, 0.2), // 12 is the floor
      ).apply(bodyColor: primary, displayColor: primary);
}
