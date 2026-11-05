import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mango/Core/theme/mango_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mango/Core/theme/mango_palette.dart';

/// Turns the Mango design system theme on or off app-wide.
const bool kUseMangoDesignSystem = true;

class ThemeController extends GetxController {
  static ThemeController get to => Get.find();
  
  final RxBool isDarkMode = false.obs;
  final RxString primaryColor = 'orange'.obs;
  final notificationsEnabled = true.obs;

  @override
  void onInit() {
    _loadTheme();
    super.onInit();
  }

  _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = prefs.getBool('isDarkMode') ?? false;
    primaryColor.value = prefs.getString('primaryColor') ?? 'orange';
  }

  Future<void> switchTheme(bool value) async {
    isDarkMode.value = value;
    await _saveTheme();
    Get.changeThemeMode(value ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> switchPrimaryColor(String color) async {
    primaryColor.value = color;
    await _saveTheme();
  }
  

  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode.value);
    await prefs.setString('primaryColor', primaryColor.value);
  }

  Color get primaryColorValue {
    switch (primaryColor.value) {
      case 'green':
        return const Color(0xFF369365);
      case 'orange':
      default:
        return const Color(0xFF369365);
    }
  }

  Color get secondaryColorValue {
    switch (primaryColor.value) {
      case 'green':
        return const Color(0xFF5FBF8A);
      case 'orange':
      default:
        return const Color(0xFFFFC324);
    }
  }

  
  Color get primaryColorLight {
    return MangoPalette.black; 
  }
}

class AppThemes {
  static ThemeData getLightTheme(String primaryColorType) {
    final Color primary = _getPrimaryColor(primaryColorType);
    final Color secondary = _getSecondaryColor(primaryColorType);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: Colors.white,
      cardColor: MangoPalette.grey100,
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.black87),
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: Colors.white,
        background: Colors.white,
        onPrimary: Colors.white,
        onSecondary: MangoPalette.black,
        onSurface: Colors.black87,
        onBackground: Colors.black87,
      ),
      textTheme: GoogleFonts.montserratTextTheme(ThemeData.light().textTheme),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
        ),
      ),
      
      extensions: <ThemeExtension<dynamic>>[
        CustomTheme(
          primaryColorLight: MangoPalette.black, 
          primaryColorDark: MangoPalette.black,  
        ),
      ],
    );
  }

  static ThemeData getDarkTheme(String primaryColorType) {
    final Color primary = _getPrimaryColor(primaryColorType);
    final Color secondary = _getSecondaryColor(primaryColorType);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: MangoPalette.black,
      cardColor: MangoPalette.black,
      dialogBackgroundColor: MangoPalette.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: MangoPalette.black,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: MangoPalette.black,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: MangoPalette.black,
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: MangoPalette.black,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MangoPalette.black,
      ),
      colorScheme: ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: MangoPalette.black,
        background: MangoPalette.black,
        onPrimary: Colors.white,
        onSecondary: MangoPalette.black,
        onSurface: Colors.white,
        onBackground: Colors.white,
      ),
      textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme),
      dividerColor: const Color(0xFF2E3B32),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
        ),
      ),
      
      extensions: <ThemeExtension<dynamic>>[
        CustomTheme(
          primaryColorLight: MangoPalette.black, 
          primaryColorDark: MangoPalette.black,
        ),
      ],
    );
  }

  static Color _getPrimaryColor(String type) {
    switch (type) {
      case 'green':
        return const Color(0xFF369365);
      case 'orange':
      default:
        return const Color(0xFF369365);
    }
  }

  static Color _getSecondaryColor(String type) {
    switch (type) {
      case 'green':
        return const Color(0xFF5FBF8A);
      case 'orange':
      default:
        return const Color(0xFFFFC324);
    }
  }

  
  // Mango design system theme (green brand, Poppins, semantic tokens).
  // Set kUseMangoDesignSystem to false to restore the previous orange theme
  // while the brand change is reviewed. Screens that hard-code colours keep
  // them until they are migrated.
  static final ThemeData lightTheme =
      kUseMangoDesignSystem ? MangoTheme.light() : getLightTheme('orange');
  static final ThemeData darkTheme =
      kUseMangoDesignSystem ? MangoTheme.dark() : getDarkTheme('orange');
}


@immutable
class CustomTheme extends ThemeExtension<CustomTheme> {
  const CustomTheme({
    required this.primaryColorLight,
    required this.primaryColorDark,
  });

  final Color primaryColorLight;
  final Color primaryColorDark;

  @override
  ThemeExtension<CustomTheme> copyWith({
    Color? primaryColorLight,
    Color? primaryColorDark,
  }) {
    return CustomTheme(
      primaryColorLight: primaryColorLight ?? this.primaryColorLight,
      primaryColorDark: primaryColorDark ?? this.primaryColorDark,
    );
  }

  @override
  ThemeExtension<CustomTheme> lerp(
    ThemeExtension<CustomTheme>? other,
    double t,
  ) {
    if (other is! CustomTheme) {
      return this;
    }
    return CustomTheme(
      primaryColorLight: Color.lerp(primaryColorLight, other.primaryColorLight, t)!,
      primaryColorDark: Color.lerp(primaryColorDark, other.primaryColorDark, t)!,
    );
  }

  
  static CustomTheme of(BuildContext context) {
    return Theme.of(context).extension<CustomTheme>()!;
  }
}


extension ThemeExtensions on BuildContext {
  
  Color get primaryColorLight => MangoPalette.black;
  
  
  Color get themePrimaryColorLight => ThemeController.to.primaryColorLight;
}