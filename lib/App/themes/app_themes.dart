import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mango/Core/theme/mango_palette.dart';

class AppThemes {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true, 
    primaryColor: MangoPalette.grey300,
    scaffoldBackgroundColor: Colors.white,
    cardColor: MangoPalette.grey200,
    appBarTheme: AppBarTheme(
      backgroundColor: MangoPalette.grey300,
      foregroundColor: MangoPalette.black,
    ),
    colorScheme: ColorScheme.light( 
      primary: MangoPalette.grey300,
      secondary: MangoPalette.green500,
      surface: Colors.white,
      background: Colors.white,
      onSurface: MangoPalette.black, 
      onBackground: MangoPalette.black, 
    ),
    textTheme: GoogleFonts.montserratTextTheme(), 
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    primaryColor: MangoPalette.black,
    scaffoldBackgroundColor: MangoPalette.black,
    cardColor: MangoPalette.grey900,
    appBarTheme: const AppBarTheme(
      backgroundColor: MangoPalette.black,
      foregroundColor: Colors.white,
    ),
    colorScheme: ColorScheme.dark( 
      primary: MangoPalette.black,
      secondary: MangoPalette.grey800,
      surface: MangoPalette.grey900,
      background: MangoPalette.black,
      onSurface: Colors.white, 
      onBackground: Colors.white, 
    ),
    textTheme: GoogleFonts.montserratTextTheme(), 
  );

  
  
  
  
}