import 'package:flutter/material.dart';

class AppTheme {
  // Colori principali
  static Color backgroundColor = const Color(0xFF11142D);
  static Color cardColor = const Color(0xFF1D1E33);
  static Color accentColor = const Color(0xFF6E7BF2);
  static Color textColor = Colors.white;
  static Color subtitleColor = Colors.grey[400]!;
  
  // Tema scuro con Material 3
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    primaryColor: accentColor,
    colorScheme: ColorScheme.dark(
      primary: accentColor,
      secondary: accentColor,
      background: backgroundColor,
      surface: cardColor,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(
        color: textColor,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: accentColor, width: 1),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      labelStyle: TextStyle(
        color: subtitleColor,
      ),
      hintStyle: TextStyle(
        color: subtitleColor,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: subtitleColor,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: backgroundColor,
      selectedItemColor: accentColor,
      unselectedItemColor: subtitleColor,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    // No cardTheme here to avoid the compatibility issue
  );
}
