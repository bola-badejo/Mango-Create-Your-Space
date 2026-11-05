// Semantic colour tokens for light and dark themes.
// Every pairing used for text or controls has a measured WCAG contrast
// ratio; see test/design_system/contrast_test.dart and Section B of the
// design system specification. Do not add a colour without a ratio.
import 'package:flutter/material.dart';

@immutable
class MangoColors extends ThemeExtension<MangoColors> {
  const MangoColors({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.surfaceElevated,
    required this.surfaceRaised,
    required this.surfaceSelected,
    required this.surfaceInput,
    required this.scrim,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.textBrand,
    required this.borderSubtle,
    required this.borderControl,
    required this.actionPrimary,
    required this.actionPrimaryPressed,
    required this.onActionPrimary,
    required this.focusRing,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.error,
    required this.errorContainer,
    required this.info,
    required this.infoContainer,
  });

  final Color bgPrimary;
  final Color bgSecondary;
  final Color surfaceElevated;
  final Color surfaceRaised;
  final Color surfaceSelected;
  final Color surfaceInput;
  final Color scrim;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;
  final Color textBrand;
  final Color borderSubtle;
  final Color borderControl;
  final Color actionPrimary;
  final Color actionPrimaryPressed;
  final Color onActionPrimary;
  final Color focusRing;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color error;
  final Color errorContainer;
  final Color info;
  final Color infoContainer;

  static const MangoColors light = MangoColors(
    bgPrimary: Color(0xFFFFFFFF),
    bgSecondary: Color(0xFFF5F6F3),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSelected: Color(0xFFE4F1E8),
    surfaceInput: Color(0xFFF5F6F3),
    scrim: Color(0x7A101310), // #101310 at 48%
    textPrimary: Color(0xFF101310), // 18.71:1 on white
    textSecondary: Color(0xFF4A544D), // >= 7.26:1
    textTertiary: Color(0xFF5C665F), // >= 5.50:1
    textDisabled: Color(0xFF9AA39C), // exempt; always paired with a disabled cue
    textBrand: Color(0xFF20563D), // 8.54:1 on white
    borderSubtle: Color(0xFFE2E5E0), // decorative only
    borderControl: Color(0xFF7F8982), // >= 3.34:1 (control boundary)
    actionPrimary: Color(0xFF28734F), // white label 5.74:1
    actionPrimaryPressed: Color(0xFF20563D), // white label 8.54:1
    onActionPrimary: Color(0xFFFFFFFF),
    focusRing: Color(0xFF28734F), // 5.74:1 against white
    success: Color(0xFF1E7A46),
    successContainer: Color(0xFFE3F4EA),
    warning: Color(0xFF8A5A00),
    warningContainer: Color(0xFFFFF1D6),
    error: Color(0xFFB3261E),
    errorContainer: Color(0xFFFCE8E6),
    info: Color(0xFF1F5FA8),
    infoContainer: Color(0xFFE5EFFB),
  );

  static const MangoColors dark = MangoColors(
    bgPrimary: Color(0xFF0B0F0C),
    bgSecondary: Color(0xFF131A15),
    surfaceElevated: Color(0xFF1B241E),
    surfaceRaised: Color(0xFF243028),
    surfaceSelected: Color(0xFF1C3326),
    surfaceInput: Color(0xFF131A15),
    scrim: Color(0xA3000000), // black at 64%
    textPrimary: Color(0xFFEEF2EE), // >= 12.15:1 on all dark surfaces
    textSecondary: Color(0xFFA9B5AC), // >= 6.47:1
    textTertiary: Color(0xFF8A978D), // >= 4.51:1
    textDisabled: Color(0xFF5E6B62),
    textBrand: Color(0xFF7FD1A3), // >= 7.56:1
    borderSubtle: Color(0xFF2E3B32),
    borderControl: Color(0xFF6E7B71), // >= 3.59:1
    actionPrimary: Color(0xFF5FBF8A), // dark label 8.55:1
    actionPrimaryPressed: Color(0xFF7FD1A3),
    onActionPrimary: Color(0xFF0B0F0C),
    focusRing: Color(0xFF7FD1A3), // 10.62:1 against bg
    success: Color(0xFF6FD39A),
    successContainer: Color(0xFF143322),
    warning: Color(0xFFF2B84B),
    warningContainer: Color(0xFF3A2A08),
    error: Color(0xFFFF8A80),
    errorContainer: Color(0xFF3D1513),
    info: Color(0xFF8AB8F5),
    infoContainer: Color(0xFF13263F),
  );

  /// Tokens are fixed per theme; overrides are intentionally not supported.
  @override
  MangoColors copyWith() => this;

  @override
  MangoColors lerp(covariant ThemeExtension<MangoColors>? other, double t) {
    if (other is! MangoColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return MangoColors(
      bgPrimary: l(bgPrimary, other.bgPrimary),
      bgSecondary: l(bgSecondary, other.bgSecondary),
      surfaceElevated: l(surfaceElevated, other.surfaceElevated),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceSelected: l(surfaceSelected, other.surfaceSelected),
      surfaceInput: l(surfaceInput, other.surfaceInput),
      scrim: l(scrim, other.scrim),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      textDisabled: l(textDisabled, other.textDisabled),
      textBrand: l(textBrand, other.textBrand),
      borderSubtle: l(borderSubtle, other.borderSubtle),
      borderControl: l(borderControl, other.borderControl),
      actionPrimary: l(actionPrimary, other.actionPrimary),
      actionPrimaryPressed: l(actionPrimaryPressed, other.actionPrimaryPressed),
      onActionPrimary: l(onActionPrimary, other.onActionPrimary),
      focusRing: l(focusRing, other.focusRing),
      success: l(success, other.success),
      successContainer: l(successContainer, other.successContainer),
      warning: l(warning, other.warning),
      warningContainer: l(warningContainer, other.warningContainer),
      error: l(error, other.error),
      errorContainer: l(errorContainer, other.errorContainer),
      info: l(info, other.info),
      infoContainer: l(infoContainer, other.infoContainer),
    );
  }
}
