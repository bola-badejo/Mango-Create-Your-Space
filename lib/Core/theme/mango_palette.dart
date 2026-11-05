// Mango primitive palette as compile-time constants.
//
// Screens that have not yet moved to semantic tokens (context.colors)
// use these instead of Material's Colors.orange / Colors.grey. They are
// const, so they work inside const widget trees.
//
// Prefer context.colors in new code: semantic tokens adapt to light and
// dark mode; these primitives do not.
import 'package:flutter/painting.dart';

export 'mango_tokens.dart';

abstract final class MangoPalette {
  // Brand green scale.
  static const Color green50 = Color(0xFFF3F8F4);
  static const Color green100 = Color(0xFFE4F1E8);
  static const Color green200 = Color(0xFFC6E3D0);
  static const Color green300 = Color(0xFF9FD0B2);
  static const Color green400 = Color(0xFF5FBF8A);

  /// Universal accent for screens not yet theme-aware: 3.81:1 on white
  /// (icons, large text) and 4.92:1 on black (text).
  static const Color green500 = Color(0xFF369365);
  static const Color green600 = Color(0xFF28734F);
  static const Color green700 = Color(0xFF20563D);
  static const Color green800 = Color(0xFF163D2C);
  static const Color green900 = Color(0xFF10271D);

  /// Near-black used in place of pure black (19.6:1 against white).
  static const Color black = Color(0xFF0B0F0C);

  // Green-tinted neutrals. Each matches the relative luminance of the
  // Material grey it replaces, so contrast is unchanged in both themes.
  static const Color grey50 = Color(0xFFF8FBF6);
  static const Color grey100 = Color(0xFFF3F6F1);
  static const Color grey200 = Color(0xFFECEFEA);
  static const Color grey300 = Color(0xFFDEE1DC);
  static const Color grey350 = Color(0xFFD4D7D2);
  static const Color grey400 = Color(0xFFBBBEB9);
  static const Color grey500 = Color(0xFF9C9F9A);
  static const Color grey600 = Color(0xFF737671);
  static const Color grey700 = Color(0xFF5F625D);
  static const Color grey800 = Color(0xFF40433E);
  static const Color grey850 = Color(0xFF2E312C);
  static const Color grey900 = Color(0xFF1E221F);
}
