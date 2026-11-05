// Builds Mango's light and dark ThemeData from tokens. Component themes
// here are what make un-migrated screens look closer to the system for
// free: Material widgets read these values automatically.
import 'package:flutter/material.dart';

import 'mango_colors.dart';
import 'mango_page_transitions.dart';
import 'mango_tokens.dart';
import 'mango_typography.dart';

abstract final class MangoTheme {
  static ThemeData light() => _build(MangoColors.light, Brightness.light);
  static ThemeData dark() => _build(MangoColors.dark, Brightness.dark);

  static ThemeData _build(MangoColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.actionPrimary,
      onPrimary: c.onActionPrimary,
      primaryContainer: c.surfaceSelected,
      onPrimaryContainer: c.textBrand,
      secondary: c.textBrand,
      onSecondary: c.bgPrimary,
      secondaryContainer: c.surfaceSelected,
      onSecondaryContainer: c.textPrimary,
      error: c.error,
      onError: c.bgPrimary,
      errorContainer: c.errorContainer,
      onErrorContainer: c.error,
      surface: c.bgPrimary,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.bgPrimary,
      surfaceContainerLow: c.bgSecondary,
      surfaceContainer: c.bgSecondary,
      surfaceContainerHigh: c.surfaceElevated,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.borderControl,
      outlineVariant: c.borderSubtle,
      scrim: c.scrim,
    );

    final text = MangoTypography.textTheme(c.textPrimary);
    final pill = const StadiumBorder();
    final labelStyle = text.labelLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
    );

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(MangoRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: MangoTypography.family,
      textTheme: text,
      scaffoldBackgroundColor: c.bgPrimary,
      canvasColor: c.bgPrimary,
      cardColor: c.surfaceElevated,
      dividerColor: c.borderSubtle,
      extensions: <ThemeExtension<dynamic>>[c],
      // Pads small controls out to 48 dp touch targets.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: mangoPageTransitionsTheme,
      focusColor: c.focusRing.withValues(alpha: 0.12),
      hoverColor: c.textPrimary.withValues(alpha: 0.08),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgPrimary,
        foregroundColor: c.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.actionPrimary,
          foregroundColor: c.onActionPrimary,
          minimumSize: const Size(64, MangoSize.buttonLarge),
          padding: const EdgeInsets.symmetric(horizontal: MangoSpace.s6),
          shape: pill,
          textStyle: labelStyle,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.actionPrimary,
          foregroundColor: c.onActionPrimary,
          minimumSize: const Size(64, MangoSize.buttonMedium),
          shape: pill,
          elevation: 0,
          textStyle: labelStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          minimumSize: const Size(64, MangoSize.buttonMedium),
          side: BorderSide(color: c.borderControl),
          shape: pill,
          textStyle: labelStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.textBrand,
          minimumSize: const Size(48, MangoSize.minTouchTarget),
          shape: pill,
          textStyle: labelStyle,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(MangoSize.minTouchTarget),
          foregroundColor: c.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceInput,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MangoSpace.s4,
          vertical: MangoSpace.s4,
        ),
        labelStyle: text.labelLarge?.copyWith(color: c.textSecondary),
        floatingLabelStyle: text.labelLarge?.copyWith(color: c.textPrimary),
        hintStyle: text.bodyMedium?.copyWith(color: c.textTertiary),
        helperStyle: text.bodySmall?.copyWith(color: c.textSecondary),
        errorStyle: text.bodySmall?.copyWith(color: c.error),
        border: inputBorder(c.borderControl),
        enabledBorder: inputBorder(c.borderControl),
        focusedBorder: inputBorder(c.focusRing, MangoSize.focusRingWidth),
        errorBorder: inputBorder(c.error),
        focusedErrorBorder: inputBorder(c.error, MangoSize.focusRingWidth),
        disabledBorder: inputBorder(c.borderSubtle),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.bgPrimary,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.surfaceSelected,
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelMedium?.copyWith(
            color: states.contains(WidgetState.selected)
                ? c.textBrand
                : c.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: MangoSize.icon,
            color: states.contains(WidgetState.selected)
                ? c.textBrand
                : c.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.bgPrimary,
        indicatorColor: c.surfaceSelected,
        selectedIconTheme: IconThemeData(color: c.textBrand),
        unselectedIconTheme: IconThemeData(color: c.textSecondary),
        selectedLabelTextStyle: text.labelLarge?.copyWith(
          color: c.textBrand,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle:
            text.labelLarge?.copyWith(color: c.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        modalBarrierColor: c.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(MangoRadius.lg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        barrierColor: c.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MangoRadius.lg),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.textPrimary,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.bgPrimary),
        actionTextColor: c.bgPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MangoRadius.md),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: c.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.actionPrimary,
        linearTrackColor: c.borderSubtle,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: MangoMotionTokens.slow,
        decoration: BoxDecoration(
          color: c.textPrimary,
          borderRadius: BorderRadius.circular(MangoRadius.sm),
        ),
        textStyle: text.bodySmall?.copyWith(color: c.bgPrimary),
      ),
    );
  }
}
