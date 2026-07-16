import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1E3A8A); // Indigo 900
  static const Color primaryLight = Color(0xFF3B82F6); // Blue 500
  static const Color primaryDark = Color(0xFF172554); // Indigo 950

  static const Color secondaryColor = Color(0xFFF59E0B); // Amber 500
  static const Color backgroundColor = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceColor = Colors.white;
  static const Color errorColor = Color(0xFFEF4444); // Red 500

  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.grey, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 15),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 14),
      ),
      iconTheme: const IconThemeData(color: primaryColor, size: 24),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: primaryLight,
        secondary: secondaryColor,
        surface: Color(0xFF0F172A),
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
    );
  }
}
