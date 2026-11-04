import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppThemes {
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true, 
    primaryColor: Colors.grey[300],
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.grey.shade200,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[300],
      foregroundColor: Colors.black,
    ),
    colorScheme: ColorScheme.light( 
      primary: Colors.grey[300]!,
      secondary: Colors.orange,
      surface: Colors.white,
      background: Colors.white,
      onSurface: Colors.black, 
      onBackground: Colors.black, 
    ),
    textTheme: GoogleFonts.montserratTextTheme(), 
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    primaryColor: Colors.black,
    scaffoldBackgroundColor: Colors.black,
    cardColor: Colors.grey[900],
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    colorScheme: ColorScheme.dark( 
      primary: Colors.black,
      secondary: Colors.grey[800]!,
      surface: Colors.grey[900]!,
      background: Colors.black,
      onSurface: Colors.white, 
      onBackground: Colors.white, 
    ),
    textTheme: GoogleFonts.montserratTextTheme(), 
  );

  
  
  
  
}